_ = require 'underscore'
pg = require 'pg'
Promise = require 'bluebird'
cors = require('cors')


express = require 'express'
app = express()

server_config =
  port: 9999
  address: "0.0.0.0"


client = new pg.Client()

# create a config to configure both pooling behavior
# and client options
# note: all config is optional and the environment variables
# will be read if the config is not present
config =
  user: 'testuser', #env var: PGUSER
  database: 'testuser', #env var: PGDATABASE
  password: 'test123', #env var: PGPASSWORD
  host: '52.44.214.221', # Server hosting the postgres database
  port: 5432, #env var: PGPORT
  max: 10, # max number of clients in the pool
  idleTimeoutMillis: 30000, # how long a client is allowed to remain idle before being closed

process.on 'unhandledRejection', (e)->
  console.error("Node 'unhandledRejection':", e.message, e.stack)



# this initializes a connection pool
# it will keep idle connections open for a 30 seconds
# and set a limit of maximum 10 idle clients
pool = new pg.Pool(config)

pool.on 'error', (err, client)->
  # if an error is encountered by a client while it sits idle in the pool
  # the pool itself will emit an error event with both the error and
  # the client which emitted the original error
  # this is a rare occurrence but can happen if there is a network partition
  # between your application and the database, the database restarts, etc.
  # and so you might want to handle it and at least log it out
  console.error('Postgres idle client error', err.message, err.stack)


q = (query, opts=[])->
  new Promise (resolve, reject)->
    pool.query query, opts, (err, res)->
      return reject(err) if err
      resolve(res)

app.use express.static('_public')
app.use(cors())

app.get '/data', (req, res)->
  onError = (err)->
    console.log(err.message, err.stack)
    res.writeHead(500, {'content-type': 'text/plain'});
    res.end('An error occurred');

  pool.query 'SELECT * FROM sales_by_month;', (err, result)->
    if err
      return onError(err)

    res.json(result)

app.get '/update-comment/:id', (req, res)->
  {quantity, comment} = req.query
  console.log "Got update comment request", [req.params.id, quantity, comment]
  q( "UPDATE sales_by_month SET quantity=$2, comment=$3 WHERE id=$1", [req.params.id, quantity, comment])
    .then (e)-> res.json("OK")
    .error (err)->
      console.error err.message, err.stack
      res.status(500).json("ERROR")

app.listen server_config.port, server_config.address, ()->
  console.log("Test app listening on port #{server_config.port}!")


