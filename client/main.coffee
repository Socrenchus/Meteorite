# Collections
Changes = new Meteor.Collection("changes")

uuid = Meteor.uuid()

# Subscriptions
Meteor.subscribe( 'code_filenames' )
Meteor.autosubscribe( ->
  Meteor.subscribe( 'code_file', root_path + Session.get( 'current_file' ) )
)

# Templates
##
_.extend( Template.file_list,
  files: ->
    results = Changes.find( {}, { fields: {filename: 1} } ).fetch()
    uniq = {}
    for r in results
      uniq[r.filename[root_path.length+1..]] = true
    return ( {filename: k} for k of uniq )
)

# Code editor

init = (filename) ->
  ta = document.getElementById("ta")
  onChangeEnabled = true
  onChange = (m, evt) ->
    # tron.log('onChange:', m, evt)
    while evt
      Changes.insert(
        filename: filename
        uuid: uuid
        date: new Date()
        text: evt.text
        from: evt.from
        to: evt.to
      )
  m = CodeMirror.fromTextArea(ta,{mode: "text/x-coffeescript", electricChars: false, indentWithTabs: false, tabSize: 2, smartIndent: true, lineNumbers: true, onChangeEnabled: onChange})
  m.focus()
  m.setSelection({line:0, ch:0}, {line:m.lineCount(), ch:0})
  changes = Changes.find({'filename':filename}, {sort: {date: 1}})

  # execute the modification on the mirror
  exec = (evt, mirror) ->
    onChangeEnabled = false
    try
      unless evt.uuid is uuid
        mirror.replaceRange(evt.text.join('\n'), evt.from, evt.to)
    finally
      Meteor.call('save_file_text', filename, m.getValue())
      onChangeEnabled = true

  date = 0
  changes.forEach( (ch) ->
    date = Math.max(new Date(ch.date).getTime(), date)
    exec(ch, m)
  )

  date = `undefined` if date is 0
  Changes.find({date: {$gt: new Date(date)}, 'filename':filename, uuid: {$ne: uuid}}).observe(
    added: (ch) ->
        exec(ch, m) if (uuid != ch.uuid && filename == ch.filename)
  )

# Backbone router
class Router extends Backbone.Router
  routes:
    "edit*path": "edit_file"
    "run/:branchname": "run_branch"

  edit_file: (path) ->
    Session.set( 'current_file', path )
    init(root_path + path)

Router = new Router()
Meteor.startup( ->
  Backbone.history.start( pushState: true ) #!SUPPRESS no_headless_camel_case
)
