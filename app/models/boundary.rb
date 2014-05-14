# == Schema Information
#
# Table name: boundaries
#
#  id    :integer          not null, primary key
#  os    :string(255)
#  name  :string(255)
#  kind  :string(255)
#  shape :spatial          geometry, 0
#  gss   :string(255)
#

class Boundary < ActiveRecord::Base
  
  attr_accessible :os, :gss, :name, :kind, :shape

end
