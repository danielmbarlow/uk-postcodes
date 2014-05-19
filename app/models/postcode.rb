# == Schema Information
#
# Table name: postcodes
#
#  id                :integer          not null, primary key
#  postcode          :string(255)
#  latlng            :spatial          point, 4326
#  council           :string(255)
#  county            :string(255)
#  electoraldistrict :string(255)
#  ward              :string(255)
#  constituency      :string(255)
#  country           :string(255)
#  parish            :string(255)
#  eastingnorthing   :spatial          point, 0
#

class Postcode < ActiveRecord::Base
  
  self.rgeo_factory_generator = RGeo::Geos.factory_generator

  set_rgeo_factory_for_column(:latlng, RGeo::Geographic.spherical_factory(:srid => 4326))
  
  ADMIN_AREAS = [:council, :county, :ward, :constituency, :parish, :electoral_district]

  def self.nearest(lat, lng, distance)
    Postcode.where("ST_DWithin(latlng, ST_Geomfromtext('POINT(#{lat} #{lng})'), #{distance})").
        order("ST_Distance(latlng, ST_Geomfromtext('POINT(#{lat} #{lng})'))")
  end

  def lat
    self.latlng.x
  end
  
  def lng
    self.latlng.y
  end
  
  def easting
    self.eastingnorthing.x
  end
  
  def northing
    self.eastingnorthing.y
  end
  
  def distance_from(lat, lng)
    d = Geodesic::dist_haversine(self.lat, self.lng, lat, lng)
    (d * 0.6214).round(4)
  end
  
  def admin_areas
    areas = {}
    ADMIN_AREAS.each do |area|
      areas[area] = self.send("#{area}_details")
    end
    areas.delete_if {|k,v| v.blank?}
  end
  
  def geohash
    hash = GeoHash.encode(self.lat, self.lng)
    "http://geohash.org/#{hash}"
  end
  
  def method_missing(method_name, *args, &blk)
    val = method_name.to_s.match(/(.+)_details/)
    unless val.nil?
      c = Code.where(:gss => self.send(val[1])).first
      area_details(c)
    else
      super
    end
  end
  
  def electoral_district_details
    unless ni?
      b = Boundary.where("kind = 'CountyElectoralDivision' AND ST_Contains(shape, ST_Geomfromtext('POINT(#{self.easting} #{self.northing})'))").first
      area_details(b)
    end
  end

  def parish_details
    unless ni?
      b = Boundary.where("kind = 'CivilParish' AND ST_Contains(shape, ST_Geomfromtext('POINT(#{self.easting} #{self.northing})'))").first
      area_details(b)
    end
  end
  
  def area_details(area)
    unless area.nil?
      {
        :name => area.name,
        :gss => area.gss,
        :os => area.os,
        :ons_uri => "http://statistics.data.gov.uk/id/statistical-geography/#{area.gss}",
        :os_uri => "http://data.ordnancesurvey.co.uk/id/#{area.os}",
        :kind => area.kind
      }
    else
      {}
    end
  end
  
  def to_csv
    CSV.generate do |csv|
      csv << [
          self.postcode,
          self.lat,
          self.lng,
          self.easting,
          self.northing,
          geohash,
          county_details[:gss],
          county_details[:name],
          council_details[:gss],
          council_details[:name],
          ward_details[:gss],
          ward_details[:name]
        ]
    end
  end
  
  def ni?
    country == "N92000002"
  end
  
end
