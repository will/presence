require 'sinatra'
require 'pg'
require 'sequel'
require 'json'
$stdout.sync = true


# here is the database schema
# create table events(id serial, client_mac macaddr, ap_mac macaddr, last_seen timestamptz, rssi int);

DB = Sequel.connect(ENV.fetch 'DATABASE_URL')
VALIDATOR = ENV.fetch 'VALIDATOR'
SECRET    = ENV.fetch 'SECRET'
class App < Sinatra::Application
  get '/events' do
    VALIDATOR
  end

  post '/events' do
    map = JSON.parse(params[:data])
    if map['secret'] != SECRET
      logger.warn "got post with bad secret: #{SECRET}"
      return
    end
    p map['probing']
    map['probing'].each do |c|
      p "client #{c['client_mac']} seen on ap #{c['ap_mac']} with rssi #{c['rssi']} at #{c['last_seen']}"
      DB[:events] << c
    end
  "ok"
  end
end


run App

