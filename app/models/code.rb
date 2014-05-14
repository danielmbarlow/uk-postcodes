# == Schema Information
#
# Table name: codes
#
#  id   :integer          not null, primary key
#  name :string(255)
#  snac :string(255)
#  os   :string(255)
#  gss  :string(255)
#  kind :string(255)
#

class Code < ActiveRecord::Base

end
