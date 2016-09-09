_ = require 'underscore'
csv = require('csv')
Promise = require 'bluebird'
moment = require 'moment'

readFile = Promise.promisify(require("fs").readFile)
writeFile = Promise.promisify(require("fs").writeFile)
csv_parse = Promise.promisify(csv.parse)
csv_stringify = Promise.promisify(csv.stringify)

load_goods_list = (filename)->
  readFile(filename)
    .then (data)-> csv_parse(data, delimiter: '\t', auto_parse: true, trim:true, columns: true)
    #.then (parsed)-> console.log "parsed:", parsed
    #.error (err)-> console.error "Error loading goods list:", err.message, err.stack


randomLp = (scale, old)->
  r = ()-> Math.floor(Math.random() * scale)
  new_rand = Math.floor(((2 * old) + r() + r()) / 4.0)

create_goods_timeline = (good, start, months, scale)->
  #current = moment(start)
  lastRandom = randomLp(scale, scale / 2 )
  price = Math.floor(Math.random() * 10000) + 5000

  for i in [0..(months - 1)]
    current = moment(start).add(i, 'months')
    lastRandom = randomLp(scale, lastRandom)
    {
        system_name: good.system
        port_location: good.station
        product_name: good.goods
        month_start: current.format("YYYY-MM-DD")
        quantity: parseInt(good.max_quantity) * lastRandom
        unit_price: price
    }


build_goods_list = (in_file, out_file, start, months, scale)->
  load_goods_list(in_file)
    .then (goods)-> return (create_goods_timeline(good, start, months, scale) for good in goods)
    .then (g)-> _.flatten(g, true)
    .then (d)-> csv_stringify(d, header: true)
    .then (str)-> writeFile(out_file, str)
    .error (err)-> console.error "Error loading goods list:", err.message, err.stack


build_goods_list("app/sql/goods_list.csv", "app/sql/time_data.csv", new Date(2014,12,1), 24, 1000)

