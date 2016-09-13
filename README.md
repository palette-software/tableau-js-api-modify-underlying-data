# Quickstart

## Pre-requisites

```bash
npm install
npm install gulp --global
```

Install the `index.html` file found in `_public` to your Tableau Server
as a web data connector (but change the address for the javascript and
css files used to point to your local server).

After the web data connector is installed, set the `URL of Published HTML file`
parameter in the test workbook to point to the newly installed web data
connector. This allow the dashboard to load the web data connector to
the right side of the screen, which in turn forwards the requests to
your development server.


A detailed explanation of this installation process can be found
in the [Tableau JavaScript API without Embedding](http://databoss.starschema.net/tableau-javascript-api-without-embedding/) blog post.

## Running the server

```bash
gulp watch serve
```

# Executive Summary

This is a Proof-of-Concept showing how to use the Tableau JS API to add
annotations to and modify the underlying data of a Tableau workbook from your web browser.

# The data

The data represents trading good prices in the galaxy (using Elite:
Dangerous rare goods as a basis, but the data itself is just a lowpassed
random series swifting around the base price.)

Its hierarchy is like:

- There are `Systems` in the Galaxy
- There are `Stations` or `Ports` in the `Systems`
- Each station in the dataset has goods only available there (rare
  goods) whose price fluctuates.


The structure of the data in the database is very simple and
denormalized:

```sql
drop table if exists sales_by_month;
create table if not exists sales_by_month (
  id serial not null primary key,
  system_name text,
  port_location text,

  product_name text,

  month_start date,

  quantity numeric(10,0),
  unit_price numeric(10,2),

  comment text
);
```

A generated base dataset is available in `app/sql/goods_list.csv`.


# The server-side

Our server needs to connect to the backing PostgreSQL database and
update the comment and quantity fields if the user requests.

We'll use Node.js to build this server.


## Connect to the database

We'll use the [NodeJS PostgreSQL driver](https://github.com/brianc/node-postgres) to connect to the backing database.

```bash
npm install pg --save
```

Lets add the requires we'll need for the postgres connection and write a
basic connection pool for our webapp (this is pretty much copy-paste
from the [Node.js Postgres example](https://github.com/brianc/node-postgres/wiki/Example):


```coffee
pg = require 'pg'


client = new pg.Client()

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
  console.error('Postgres idle client error', err.message, err.stack)
```

So now we have a connection pool to the postgres database. Lets write a
quick helper to run a query and return a promise. We'll use the
[Bluebird JS Promise library](http://bluebirdjs.com/docs/getting-started.html)
for the Promises.

```
npm install bluebird --save
```

```coffee
Promise = require 'bluebird'

q = (query, opts=[])->
  new Promise (resolve, reject)->
    pool.query query, opts, (err, res)->
      return reject(err) if err
      resolve(res)
```


## Create the server

Now that the database connection is set up, lets add the HTTP server
bits. We'll be using the [ExpressJS framework](https://expressjs.com/)
to implement this:

```bash
npm install express --save
```

```coffee

express = require 'express'
app = express()

server_config =
  port: 9999
  address: "0.0.0.0"


# Use the '_public' folder as static document root
app.use express.static('_public')

# Handler for updating the comment/quantity on a row
app.get '/update-comment/:id', (req, res)->
  # [...]

app.listen server_config.port, server_config.address, ()->
  console.log("Test app listening on port #{server_config.port}!")
```

This should be fairly trivial:

- we import express and create an instance that will be our application
- we set the `_public` folder as our static document root and server
  static files from there
- we create a handler that changes the comment for a row
- then start the server by binding it to the port and address specified
  by the config.


### The update handler

Now lets write the handler that updates the database. 

- This handler gets an `id` in the URL plus a `quantity` and a `comment`
  field in the request body.
- Using this id and attributes, it updates the record then responds with
  an "OK" or an "ERROR"


```coffee
app.get '/update-comment/:id', (req, res)->
  {quantity, comment} = req.query
  q( "UPDATE sales_by_month SET quantity=$2, comment=$3 WHERE id=$1", [req.params.id, quantity, comment])
    .then (e)-> res.json("OK")
    .error (err)->
      console.error err.message, err.stack
      res.status(500).json("ERROR")
```



### Cross-origin requests

Since our web server will be responding to a web page under a different
domain, we'll need to emit proper CORS headers so browsers accept our
responses. Doing this in Express is very easy:


```bash
npm install cors --save
```

Then add the cors to the application as middleware:

```coffee
cors = require('cors')

app.use(cors())
```


This completes our server.


# The client side

Lets look at the logic on the client side:

- On load it should tell us to select a commodity from the Tableau
  report.

- If we click on any point in the price graphs, a form should be
  displayed allowing us to add/change/clear the comment and the quantity
  in the underlying data in the database at that point

- After submitting the form, the database should be updated and the
  Tableau report should be refreshed to reflect the changes made.



## Creating the form and the "select" message


We'll put this form directly into the Web Data Connector HTML file:

```html
  <div class="container">

    <div id="editor-wrap"  style='display:none;'>

      <div class="row">
        <div class="col-sm-12">
          <div id="intro-text">
            <h3>Edit the selected data</h3>
            <p>
            </p>
          </div>
        </div>
      </div>

      <div class="row">
        <div class="col-sm-12">

          <!-- The actual editor form -->
          <div class='editor-form-wrap'>
            <form id="editor-form">

              <input type="hidden" name="id" value="" />

              <table class='table table-condensed info-table'>
                <tbody>
                  <tr>
                    <th>System name</th>
                    <td data-field="system_name"><td>
                  </tr>
                  <tr>
                    <th>Port location</th>
                    <td data-field="port_location"><td>
                  </tr>
                  <tr>
                    <th>Month start</th>
                    <td data-field="month_start"><td>
                  </tr>
                  <tr>
                    <th>Unit price</th>
                    <td>$<span data-field="unit_price"></span><td>
                  </tr>

                  <tr>
                    <th>
                      <label for="quantity-input">Quantity</label>
                    </th>
                    <td>
                      <input type="number" class="form-control" id="quantity-input" name='quantity' placeholder="New quantity">
                    </td>
                  </tr>

                  <tr>
                    <th>
                      <label for="comment-input">Comment for this point</label>
                    </th>
                    <td >
                      <textarea name='comment' placeholder='Add a comment...' id='comment-input' class='form-control'></textarea>
                    </td>
                  </tr>

                </tbody>
              </table>


              <a href="#" class="btn btn-default" data-submit="true" data-url="http://52.44.214.221:9999/update-comment/{{id}}">Submit</a>

            </form>
          </div>

        </div>
      </div>
    </div>

    <div id='nodata-wrap'>
      <div class="row">
        <div class="col-sm-12">
          <div id="intro-text">
            <h3>Select a data point</h3>
            <p>
              To edit the data and the comments
            </p>
          </div>
        </div>
      </div>

    </div>

  </div>

```

### Form helper for easy back-and-forth

Then lets create some helper for dealing with this form:


```coffee
# Updates form fields in parent selector from a hash of name => value
# pairs
updateFormFields = (parent, data)->
  $parent = $(parent)
  for k,v of data
    # Skip the tableau %null%-S
    v = "" if v == TABLEAU_NULL
    $("input[name=#{k}], textarea[name=#{k}]", $parent.el).val(v)
    $("[data-field=#{k}]", $parent.el).text(v)
```

This function takes a jquery selector and a javascript object and sets
the values/contents of each form and html element with a corresponding
`name` or `data-field` attribute.

```coffee
getFormFields = (parent)->
  o = {}
  $("input, textarea, [data-field]").each ()->
    $t = $(this)
    o[$t.attr('name')] = $t.val()
  o
```

This function does the exact inverse: it collects all data from the
elements in the form.


### More form helpers for showing/hiding

To be able to show/hide the form and the 'Select a product' message,
lets add some helpers

```coffee
EDITOR_SELECTOR = "#editor-wrap"
NODATA_SELECTOR = "#nodata-wrap"

showEditor = ()-> $(NODATA_SELECTOR).hide(100, ()-> $(EDITOR_SELECTOR).show())
hideEditor = ()-> $(EDITOR_SELECTOR).hide(100, ()-> $(NODATA_SELECTOR).show())
toggleEditor = (show)-> if show then showEditor() else hideEditor()
```

While we are at the form, lets also create a function that sets up the
submit action to map to our submit handler function.


```coffee
initEditorForm = (selector)->
  $editorForm = $(selector)
  $("[data-submit=true]", $editorForm.el).click submitForm
  $editorForm
```


We'll come back to this `submitForm` function later when we submit the
form.


## Connect to the Tableau JS API

Lets define a few functions that allow us to connect to the
tableau JS API in the dashboard frame while keeping line lengths sane
(this process has been explained in detail in the
[Tableau JavaScript API without Embedding](http://databoss.starschema.net/tableau-javascript-api-without-embedding/) blog post).


```coffee
# Quick accessors for accessing the tableau bits on the parent page
getTableau = ()-> parent.parent.tableau
getCurrentViz = ()-> getTableau().VizManager.getVizs()[0]

# Returns the current worksheet.
# The path to access the sheet is hardcoded for now.
getCurrentWorksheet = ()-> getCurrentViz().getWorkbook().getActiveSheet().getWorksheets()[0]
```

We also need to export our initializer function so it can be ran on
document load:

```coffee
@appApi = {
  initEditor
}
```

## Create some helpers

Also lets declare a simple helper that wraps a function in a try/catch
block, so any exceptions wont be swallowed by the JS Promise
implementation used:

```coffee
# Because handlers in promises swallow errors and
# the error callbacks for Promises/A are flaky,
# we simply use this function to wrap calls
errorWrapped = (context, fn)->
  (args...)->
    try
      fn(args...)
    catch err
      console.error "Got error during '", context, "' : ", err.message, err.stack
```



## Set up an event handler

We want to show a SanKey graph when the user selects a country on our
dashboard. To do this, we'll hook into the Tableau `MARKS_SELECTION`
event.

```coffee
initEditor = ->
  # Setup the editor form
  $editorForm = initEditorForm("#editor-form")

  # Get the tableau bits from the parent.
  tableau = getTableau()

  # Error handler in case getting the data fails in the Promise
  onDataLoadError = (err)->
    console.err("Error during Tableau Async request:", err)

  # Handler for loading and converting the tableau data to chart data
  onDataLoadOk = errorWrapped "Getting data from Tableau", (table)-> # [...]

  # Handler that gets the selected data from tableau and sends it to the chart
  # display function
  updateEditor = ()->
    getCurrentWorksheet()
      .getUnderlyingDataAsync({maxRows: 1, ignoreSelection: false, includeAllColumns: true, ignoreAliases: true})
      .then(onDataLoadOk, onDataLoadError )

  # Add an event listener for marks change events that simply loads the
  # selected data to the chart
  getCurrentViz().addEventListener( tableau.TableauEventName.MARKS_SELECTION,  updateEditor)


@appApi = {
  initEditor
}
```

Lets walk through the important bits of code from the back

```coffee
getCurrentViz().addEventListener( tableau.TableauEventName.MARKS_SELECTION,  updateEditor)
```

This tells Tableau to call updateEditor on selecting anything on the
dashboard.

```coffee
  updateEditor = ()->
    getCurrentWorksheet()
      .getUnderlyingDataAsync({maxRows: 1, ignoreSelection: false, includeAllColumns: true, ignoreAliases: true})
      .then(onDataLoadOk, onDataLoadError )
```

We use the Tableau JS API to get the underlying data:

- we DO want all columns not just the displayed ones
- we DONT care about aliases, we dont use them in our workbook
- we DO only care about the data related to the selection
- we ONLY want the first row from the underlying data (if we select a
  complete row, we want to ignore that selection)

`getUnderlyingDataAsync()` returns a Promise we need to handle, `.then` is the Promise way of saying:

- if the everything went OK, call `onDataLoadOk` with the loaded data
- if anything failed, call `onDataLoadError` with the exception (where
  we simply log it to the console)


## Converting Tableau data to JavaScript data


So lets assume that the request for the underlying data was successful
and Tableau calls us back with the data. Its in Tableau's own format (an
array of Tableau objects), so lets convert it to a native POD (plain old
data) format.

### Getting the column indices

Tableau needs column indices instead of column names, which is very
uncomfortable and error prone, so lets do two little helper functions:


The first one takes a tableau table and a list of column names we are
interested in and returns a javascript object where the keys are the
field names we've given and the values are the field indices:

```coffee
# Takes a table and returns a "COLUMN_NAME" => COLUMN_IDX map
getColumnIndexes = (table, required_keys)->
  # Create a column name -> idx map
  colIdxMaps = {}
  for c in table.getColumns()
    fn = c.getFieldName()
    if fn in required_keys
      colIdxMaps[fn] = c.getIndex()
  colIdxMaps
```

The second helper takes a Tableau Row object and the fieldname/index map
object returned by `getColumnIndexes()` and returns a POD javascript
object with the field names mapped to the values [using `_.mapObject()`](http://underscorejs.org/#mapObject):


```coffee
# Takes a Tableau Row and a "COL_NAME" => COL_IDX map and returns
# a new object with the COL_NAME fields set to the corresponding values
convertRowToObject = (row, attrs_map)->
  _.mapObject attrs_map, (id, name)-> row[id].value
```

### Filling the form

Lets write the first steps of the `onDataLoadOk` function using the
helpers we have created:

```coffee
# Handler for loading and converting the tableau data to chart data
onDataLoadOk = errorWrapped "Getting data from Tableau", (table)->
    # Decompose the ids
    col_indexes = getColumnIndexes(table, ["id", "month_start", "system_name", "port_location", "product_name", "quantity", "unit_price", "comment"])

    data = table.getData()

    # Show-hide the editor if we have data
    toggleEditor(data.length == 1)

    graphData = _.first( _.map(table.getData(), (row)-> convertRowToObject(row, col_indexes)))

    errorWrapped( "Updating form fields", updateFormFields)( $editorForm, graphData )
```

With the helpers we've written this function should be fairly trivial to
understand:

- get the column indexes for the properties we care about
- transform the Tableau row(s) into javascript POD rows and take only
  the first of them
- then update the form to set all inputs/fields to the proper value

### Submitting the form


In our `initEditorForm()` function we have assgined a submission handler
for our form called `submitForm`. Lets write this function:

- first get all data the user has input to the form
- then build a URL for submission (we have to include the Id)
- then submit the form to the server
- and if we were succesful, refresh the Tableau dashboard so the user
  can see the change.


```coffee

submitForm = (e)->
  # dont follow up
  e.preventDefault()
  # Collect the form data
  formData = getFormFields('#editor-form')
  # replace the submit url with the proper fields
  submit_url = $(this).data('url').replace /\{\{([a-z_]+)\}\}/g, (m, name)-> formData[name]

  $.get(submit_url, _.pick(formData, "id", "quantity", "comment"))
    .done ()->
      # Update the tableau workbook after we have the data
      getCurrentViz().refreshDataAsync()
    .fail (err)-> console.error "Error getting the data:", err.message, err.stack

```

The onyl tricky part here is using the `data-url` attribute of our
submit control to tell us where we want to submit our form (we could
have set the forms `action` attribute if we want to be semantically
correct about that, but since we are templating the string, that would
result in a disconnect between the semantical meaning of the `action`
attribute and the URL it actually calls).


And our POC should be complete at this point.
