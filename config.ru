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
API_PASS  = ENV.fetch 'API_PASS'

class App < Sinatra::Application
  helpers do
    def protected!
      return if authorized?
      headers['WWW-Authenticate'] = 'Basic realm="Restricted Area"'
      halt 401, "Not authorized\n"
    end

    def authorized?
      @auth ||=  Rack::Auth::Basic::Request.new(request.env)
      @auth.provided? and @auth.basic? and @auth.credentials and @auth.credentials.last == API_PASS
    end
  end

  get '/where' do
    protected!
    name = params['name']
    result = DB[<<-SQL, "#{name}@heroku.com"].all
SELECT DISTINCT ON(type)
  email, type, descr, floor, x, y, rssi,
  date_part('minutes', now() - last_seen) AS min_ago, last_seen
FROM people
LEFT OUTER JOIN events
  ON people.mac = client_mac
  AND last_seen > (now() - '00:10:00'::interval)
LEFT OUTER JOIN aps
  ON aps.mac = ap_mac
WHERE email = ?
ORDER BY type, rssi/10 DESC, last_seen;
SQL
    JSON.dump(result)
  end


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

