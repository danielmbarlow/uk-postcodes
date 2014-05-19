class PostcodeController < ApplicationController
  include PostcodeHelper
  
  caches_page :index, :show
  
  before_filter(:only => [:show, :nearest]) { alternate_formats [:json, :xml, :rdf, :csv, :n3] }

  def index
    
  end
  
  def show
    if params[:id].match(/\s/) || params[:id].match(/[a-z]/)
      postcode = params[:id].gsub(' ', '').upcase
      params[:format] ||= "html"
      redirect_to postcode_url(postcode, format: params[:format]), status: "301"
      return
    end
    
    if params[:callback] && params[:format] == 'json' && !request.original_fullpath.match(/jsonp/)
      params[:format] = "jsonp"
      redirect_to postcode_url(params[:id], params), status: "301" and return 
    end
        
    p = UKPostcode.new(params[:id])
    postcode = p.norm
    
    render_error(404, "Postcode #{p.to_s} is not valid") and return unless p.valid?
    
    @postcode = Postcode.where(:postcode => postcode).first
    
    if postcode == "" || @postcode.nil?
      render_error(404, "Postcode #{p.to_s} cannot be found")
      return
    else    
      respond_to do |format|
        format.html
        format.json
        format.xml
        format.rdf { show_rdf(@postcode, :rdfxml) }
        format.n3 { show_rdf(@postcode, :ntriples) }
        format.csv { render :text => @postcode.to_csv }
      end
    end
  end
  
  def nearest
    if params[:postcode]
      p = UKPostcode.new(params[:postcode])
      postcode = Postcode.where(:postcode => p.norm).first
      params[:lat] = postcode.lat
      params[:lng] = postcode.lng
      @postcode = postcode.postcode
    else
      render_error(422, "You must specify a latitude and longitude") and return if params[:lat].blank? || params[:lng].blank?
      @postcode = nil
    end
    
    @lat = params[:lat].to_f
    @lng = params[:lng].to_f
    
    params[:miles] ||= params[:distance]
    
    render_error(422, "You must specify a distance") and return if params[:miles].blank?    
    render_error(422, "The maximum radius is 100 miles") and return if params[:miles].to_i > 100
        
    distance = params[:miles].to_f * 1609.344

    @postcodes = params[:miles].to_i > 5 ? get_nearest_postcode_areas(@lat, @lng, distance) :
                                                                get_nearest_postcodes(@lat, @lng, distance)

    respond_to do |format|
      format.html
      format.json
      format.xml
      format.rdf { nearest_rdf(@postcodes, :rdfxml) }
      format.n3 { nearest_rdf(@postcodes, :ntriples) }
      format.csv do
        csv = []
        @postcodes.each do |postcode|
          csv << postcode.to_csv
        end
        render :text => csv.join()
      end
    end
  end

  def get_nearest_postcodes(lat, lng, distance)
    Postcode.nearest(lat,lng,distance)
  end

  def get_nearest_postcode_areas(lat, lng, distance)
    Postcode.nearest_postcode_areas(lat,lng,distance)
  end

  def reverse
    if params[:latlng]
      latlng = params[:latlng].split(",")
      if params[:latlng] =~ /\.html|\.xml|\.json|\.rdf/
        params[:format] = params[:latlng].split(".").last
      end
      params[:lat] = latlng[0]
      params[:lng] = latlng[1]
    end
    
    if params[:lat].blank? || params[:lng].blank?
      render_error(422, "You must specify a latitude and longitude") and return
    end
    
    params[:format] ||= "html"
    
    postcodes = Postcode.where("ST_DWithin(latlng, 'POINT(#{params[:lat].to_f} #{params[:lng].to_f})', 1609.344)")
                              .order("ST_Distance(latlng, 'POINT(#{params[:lat].to_f} #{params[:lng].to_f})')")
                                  
    if postcodes.count == 0
      render_error(404, "No postcode found for #{params[:lat]},#{params[:lng]}")
      return
    else
      postcode = postcodes.first
      p = postcode.postcode.gsub(" ", "")
      redirect_to postcode_url(p, format: params[:format]), status: "303"
    end
  end
  
  def search
    p = UKPostcode.new(params[:q])
    
    render_error(404, "Postcode #{p.to_s} is not valid") and return unless p.valid?
    
    postcode = p.norm.gsub(" ", "")    
    redirect_to postcode_url(postcode, format: params[:format]), status: "303"
  end

end