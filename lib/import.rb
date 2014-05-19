require 'csv'
require 'breasal'
require 'uk_postcode'
require 'geo_ruby/shp'
require 'zip/filesystem'
require 'net/http'
require 'open-uri'

class Import

  def self.setup
    
  end
  
  def self.postcodes(data_set=nil)
    if data_set == :test
      puts 'Reading TEST data'
      path = test_postcode_path
    else
      path = postcode_path
    end

    zip = Zip::File.open(path)
    lines = []
    zip.file.foreach("NSPL_AUG_2013_UK.csv") do |line|
      lines << line
      if lines.size >= 1000
        rows = CSV.parse(lines.join, {:headers => true})
        save rows
        lines = []
      end
    end
    rows = CSV.parse(lines.join, {:headers => true})
    save rows
  end
  
  def self.save(rows)
    rows.each do |row|
      p = UKPostcode.new(row[0])
      if p.valid?
        postcode = p.norm      
        easting = row[6].to_i
        northing = row[7].to_i
        county = row[10]
        council = row[11]
        ward = row[12]
        country = row[15]
        constituency = row[17]
    
        if country == "N92000002"
          en = Breasal::EastingNorthing.new(easting: easting, northing: northing, type: :ie)
        else
          en = Breasal::EastingNorthing.new(easting: easting, northing: northing)
        end
    
        ll = en.to_wgs84
    
        Postcode.create(:postcode        => postcode,
                        :eastingnorthing => "POINT(#{easting} #{northing})",
                        :latlng          => "POINT(#{ll[:latitude]} #{ll[:longitude]})",
                        :county          => county,
                        :council         => council,
                        :ward            => ward,
                        :constituency    => constituency,
                        :country         => country
                        )
      end
    end
  end

  def self.test_postcode_path
    path = Rails.root.join('lib', 'data', 'test_postcodes.zip')
  end

  def self.postcode_path
    path = Rails.root.join('lib', 'data', 'postcodes.zip')
  end
  
  def self.parishes
    file = download_boundaries
    unzip_boundaries(file, 'parish_region')
    import_boundaries('parish_region', 'CivilParish')
  end
  
  def self.electoraldistricts
    file = download_boundaries
    unzip_boundaries(file, 'county_electoral_division_region')
    import_boundaries('county_electoral_division_region', 'CountyElectoralDivision')
  end
  
  def self.download_boundaries
    url = "http://parlvid.mysociety.org/os/bdline_gb-2013-10.zip"
    file = Rails.root.join('lib', 'data', 'boundaries.zip')
    unless File.exist?(file)
      puts("... downloading boundaries from #{url}")
      open(file, 'wb') do |file|
          pbar = nil
          file << open(url,
                       :content_length_proc => lambda {|t|
                         if t && 0 < t
                           pbar = ProgressBar.create(:title => "Downloading", :total => t)
                         end
                       },
                       :progress_proc => lambda {|s|
                         pbar.progress = s if pbar
                       }
          ).read
        end
    end
    file
  end
  
  def self.unzip_boundaries(file, shp)
    zip = Zip::File.open(file)
    destination = Rails.root.join('lib', 'data', shp)
    FileUtils.mkdir_p(destination) unless File.exist?(destination)
    ['dbf', 'prj', 'shp', 'shx'].each do |ext|
      filename = "#{shp}.#{ext}"
      f = destination.join(filename)
      output_file = "Data/#{filename}"
      unless File.exist?(f)
        puts "Extracting #{output_file}"
        zip.extract(output_file, f)
      end
    end
  end
  
  def self.import_boundaries(filename, type)
    file = Rails.root.join('lib', 'data', filename, filename).to_s
    GeoRuby::Shp4r::ShpFile.open(file) do |shp|
      pbar = ProgressBar.create(:title => '... boundaries')
      shp.each do |shape|
        name = shape.data['NAME'][0..-4]
        code = "7" + shape.data['UNIT_ID'].to_s.rjust(15, '0')
        gss = shape.data['CODE']
        geom = shape.geometry.as_wkt
        
        unless code == "7000000000000000" || shape.data['NAME'].match(/(DET)/)             
          
          Boundary.create(:name  => name,
                          :os    => code,
                          :gss   => gss,
                          :kind  => type,
                          :shape => geom
                          )

                          
        end

        pbar.progress += 1/shp.record_count
      end
    end
  end
  
  def self.add_extras
    ["electoraldistrict", "parish"].each do |type|
      boundaries = Boundary.where(:type => type)
      boundaries.each do |boundary|
        Postcode.within_polygon(eastingnorthing: boundary.shape).each do |postcode|
          postcode.send("#{type}=", boundary.code)
          postcode.save
        end
        puts boundary.name
      end
    end
  end
    
  def self.codes
    path = Rails.root.join('lib', 'data', 'codes.zip')
    zip = Zip::File.open(path)
    
    codes = {
      :council      => "basic_district_borough_unitary_info.nt",
      :ward         => "basic_district_borough_unitary_ward_info.nt",
      :county       => "basic_county_info.nt",
      :constituency => "basic_westminster_const_info.nt"
    }
    
    codes.each do |type, file|
      result = zip.file.read("codes/#{file}")
      areas = {}

      RDF::NTriples::Reader.new(result) do |reader|
        reader.each_statement do |statement|
          @s = statement
          areas[@s.subject.to_s] ||= {}
          areas[@s.subject.to_s][@s.predicate.to_s] = @s.object.to_s
        end
      end

      areas.each do |k, v|
        Code.create(:name   => v['http://www.w3.org/2000/01/rdf-schema#label'],
                    :os     => k.split('/').last,
                    :gss    => v['http://data.ordnancesurvey.co.uk/ontology/admingeo/gssCode'],
                    :kind   => v['http://www.w3.org/1999/02/22-rdf-syntax-ns#type'].split('/').last
                    )
      end
    end
  end
  
  def self.ni_codes
    codes = {
      :council      => "ni_councils.csv",
      :ward         => "ni_wards.csv",
      :constituency => "ni_constituencies.csv"
    }
    
    codes.each do |type, file|
      file = Rails.root.join('lib', "data/#{file}").to_s
      
      if type == :council
        type = "District"
      else
        type = "DistrictWard"
      end
      
      CSV.foreach(file) do |row|
        Code.create(:name => row[1],
                    :os   => nil,
                    :gss  => row[0],
                    :kind => type
                    )
      end
    end
  end
  
end