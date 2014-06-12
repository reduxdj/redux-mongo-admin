###
main.coffee
###
# remove trailing slash from base url

# middleware to expose some helper functions and vars to templates

# routes
index = (req, res) ->
  res.render "admin/index",
    title: "Admin"

  return
list = (req, res) ->
  console.log info
  p = req.params.path
  m = info[p].model
  Model = mongoose.model(m)
  page = ((if req.param("page") > 0 then req.param("page") else 1)) - 1
  perPage = 30
  options =
    perPage: perPage
    page: page

  Model.list options, (err, results) ->
    return res.render("admin/500")  if err
    Model.count().exec (err, count) ->
      res.render "admin/list",
        title: capitalizeFirstLetter(p)
        list: info[p].list
        fields: info[p].fields
        data: results
        path: p
        page: page + 1
        pages: Math.ceil(count / perPage)

      return

    return

  return
edit = (req, res) ->
  p = req.params.path
  id = req.params.id
  meta = info[p]
  Model = mongoose.model(meta.model)
  Model.load id, (err, doc) ->
    return res.render("admin/500")  if err
    doc = new Model()  unless doc
    processEditFields meta, doc, ->
      res.render "admin/edit",
        meta: meta
        doc: doc
        path: p
        edit: meta.edit
        field: meta.fields

      return

    return

  return
save = (req, res) ->
  id = req.params.id
  p = req.params.path
  Model = mongoose.model(info[p].model)
  Model.findOne
    _id: id
  , (err, doc) ->
    console.log err  if err
    processFormFields info[p], req.body[p], ->
      unless id
        doc = new Model(req.body[p])
        doc.password = "123change"
      else
        updateFromObject doc, req.body[p]
      doc.save (err) ->
        console.log err  if err
        res.redirect base_url + "/" + p

      return

    return

  return
del = (req, res) ->
  id = req.params.id
  p = req.params.path
  Model = mongoose.model(info[p].model)
  Model.remove
    _id: id
  , (err) ->
    console.log err  if err
    res.redirect base_url + "/" + p

  return

###
Helper functions
###
capitalizeFirstLetter = (string) ->
  string.charAt(0).toUpperCase() + string.slice(1)
updateFromObject = (doc, obj) ->
  for field of obj
    doc[field] = obj[field]
  return
getType = (obj) ->
  ({}).toString.call(obj).match(/\s([a-zA-Z]+)/)[1].toLowerCase()
processEditFields = (meta, doc, cb) ->
  f = undefined
  Model = undefined
  field = undefined
  fields = []
  count = 0 # ToDo: change this to an array of fields to process
  for f of meta.edit
    continue
  return cb()  unless count
  for f of fields
    field = meta.fields[fields[f]]
    Model = mongoose.model(field.model)
    Model.find {}, field.display,
      sort: field.display
    , (err, results) ->
      console.log err  if err
      field["values"] = results.map((e) ->
        e[field.display]
      )
      count--
      cb()  if count is 0

  return
processFormFields = (meta, body, cb) ->
  f = undefined
  field = undefined
  Model = undefined
  query = {}
  fields = []
  count = 0
  for f of meta.edit
    if meta.fields[meta.edit[f]].widget is "ref"
      fields.push meta.edit[f]
      count++
  return cb()  unless count
  for f of fields
    field = meta.fields[fields[f]]
    Model = mongoose.model(field.model)
    query[field.display] = body[fields[f]]
    Model.findOne query, (err, ref) ->
      console.log err  if err
      body[field.field] = ref["_id"]
      count--
      cb()  if count is 0

  return
path = require("path")
paths = []
info = {}
mongoose = undefined
base_url = undefined
path_url = undefined
exports.add = (model_info) ->
  paths.push model_info.path
  info[model_info.path] = model_info
  return

exports.config = (app, mongoose_app, base) ->
  mongoose = mongoose_app
  base_url = base.replace(/\/$/, "")
  app.use "/admin", (req, res, next) ->
    res.locals.capitalizeFirstLetter = capitalizeFirstLetter
    res.locals.base = base_url
    res.locals.menu = paths
    next()
    return

  app.get path.join(base, "/"), index
  app.get path.join(base, "/:path/:id/edit"), edit
  app.get path.join(base, "/:path/new"), edit
  app.get path.join(base, "/:path"), list
  app.post path.join(base, "/:path/:id/delete"), del
  app.post path.join(base, "/:path/:id"), save
  app.post path.join(base, "/:path"), save
  return