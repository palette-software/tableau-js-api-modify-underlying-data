# Keep the current chart so we can manip it later
#myChart = null

# Quick accessors for accessing the tableau bits on the parent page
getTableau = ()-> parent.parent.tableau
getCurrentViz = ()-> getTableau().VizManager.getVizs()[0]
# Returns the current worksheet.
# The path to access the sheet is hardcoded for now.
getCurrentWorksheet = ()-> getCurrentViz().getWorkbook().getActiveSheet().getWorksheets()[0]

# Because handlers in promises swallow errors and
# the error callbacks for Promises/A are flaky,
# we simply use this function to wrap calls
errorWrapped = (context, fn)->
  (args...)->
    try
      fn(args...)
    catch err
      console.error "Got error during '", context, "' : ", err


# Takes a table and returns a "COLUMN_NAME" => COLUMN_IDX map
getColumnIndexes = (table, required_keys)->
  # Create a column name -> idx map
  colIdxMaps = {}
  for c in table.getColumns()
    fn = c.getFieldName()
    if fn in required_keys
      colIdxMaps[fn] = c.getIndex()
  colIdxMaps

# Takes a Tableau Row and a "COL_NAME" => COL_IDX map and returns
# a new object with the COL_NAME fields set to the corresponding values
convertRowToObject = (row, attrs_map)->
  o = {}
  for name, id in attrs_map
    o[name] = row[id].value
  o


# Updates form fields in parent selector from a hash of name => value
# pairs
updateFormFields = (parent, data)->
  $parent = $(parent)
  for k,v of data
    $("input[name=#{k}]", $parent.el).val(v)
    $("[data-field=#{k}]", $parent.el).text(v)

getFormFields = (parent)->
  o = {}
  $("input").each ()->
    $t = $(this)
    o[$t.attr('name')] = $t.val()
  o


# FORM TOOLS
# ==========

submitForm = (e)->
  # dont follow up
  e.preventDefault()
  # Collect the form data
  formData = getFormFields('#editor-form')
  # replace the submit url with the proper fields
  submit_url = $(this).data('url').replace /\{\{([a-z_]+)\}\}/g, (m, name)-> formData[name]

  $.get(submit_url)
    .done ()-> console.log "Data sent"
    .fail (err)-> console.error "Error getting the data:", err.message, err.stack


initEditorForm = (selector)->
  $editorForm = $(selector)
  $("[data-submit=true]", $editorForm.el).click submitForm
  $editorForm


# TABLEAU HOOKS
# ============

initEditor = ->
  $editorForm = initEditorForm("#editor-form")

  # Get the tableau bits from the parent.
  tableau = getTableau()

  # Error handler in case getting the data fails in the Promise
  onDataLoadError = (err)->
    console.err("Error during Tableau Async request:", err)

  # Handler for loading and converting the tableau data to chart data
  onDataLoadOk = errorWrapped "Getting data from Tableau", (table)->
      # Decompose the ids
      col_indexes = getColumnIndexes(table, ["id", "month_start", "system_name", "port_location", "product_name", "quantity"])


      graphDataByCategory = _.chain(table.getData())
        .map (row)-> convertRowToObject(row, col_indexes)
        .first()
        .value()

      errorWrapped( "Updating form fields", updateFormFields)( $editorForm, graphDataByCategory )

  # Handler that gets the selected data from tableau and sends it to the chart
  # display function
  updateEditor = ()->
    getCurrentWorksheet()
      .getUnderlyingDataAsync({maxRows: 1, ignoreSelection: false, includeAllColumns: true, ignoreAliases: true})
      .then(onDataLoadOk, onDataLoadError )

  # Add an event listener for marks change events that simply loads the
  # selected data to the chart
  getCurrentViz().addEventListener( tableau.TableauEventName.MARKS_SELECTION,  updateEditor)



#initEditor = ->
  #$editorForm = initEditorForm("#editor-form")

  #errorWrapped( "Updating form fields", updateFormFields) '#editor-form',
    #id: "2"
    #system_name: "Lyrae"
    #port_location: "Langford Enterprise"
    #product_name: "Ultra-Compact Processor"
    #month_start: "2015-01-01"
    #quantity: 400
    #unit_price: 14335.00


@appApi = {
  initEditor
}
