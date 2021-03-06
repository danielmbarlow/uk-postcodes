require 'import'

namespace :import do

  namespace :test do
    desc "Import test Postcodes"
    task :postcodes => :environment do
      Import.postcodes :test
    end
  end

  desc "Import Postcodes"
  task :postcodes => :environment do
    Import.postcodes
  end
  
  desc "Import Electoral districts"
  task :electoral => :environment do
    Import.electoraldistricts
  end

  desc "Import Parishes"
  task :parish => :environment do
    Import.parishes
  end
  
  desc "Import boundaries"
  task :boundaries => :environment do
    puts "Importing electoral district ..."
    Import.electoraldistricts

    puts "Importing parish ..."
    Import.parishes
  end

  desc "Import Codes"
  task :code => :environment do
    Import.codes
    Import.ni_codes
  end
  
  desc "Import all"
  task :all => :environment do
    puts 'Importing postcodes'
    Import.postcodes
    puts '... done.'

    puts 'Importing codes'
    Import.codes
    puts '... done'

    puts 'Importing NI codes'
    Import.ni_codes
    puts '... done'

    puts 'Importing electoral districts'
    Import.electoraldistricts
    puts '... done'

    puts 'Importing parishes'
    Import.parishes
    puts '... done'
  end

end