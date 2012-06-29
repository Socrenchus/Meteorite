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

`function init(filename) {
  var ta = document.getElementById("ta")
  var onChangeEnabled = true
  function onChange(m, evt){
    // console.log('onChange:', m, evt)
    while (evt) {
      if (onChangeEnabled) {
        Changes.insert({'filename': filename, uuid: uuid, date: new Date(), text: evt.text, from: evt.from, to: evt.to})
      }
      //exec(evt, mirror)
      evt = evt.next
    }
  }
  m = CodeMirror.fromTextArea(ta, {mode: "text/x-coffeescript", tabMode: "indent", electricChars: false, indentWithTabs: false, tabSize: 2, smartIndent: false, onChange: onChange});
  m.focus();
  m.setSelection({line:0, ch:0}, {line:m.lineCount(), ch:0});
  var changes = Changes.find({'filename':filename}, {sort: {date: 1}})
  // execute the modification on the mirror
  function exec(evt, mirror) {
    onChangeEnabled = false
    try {
      if (evt.uuid != uuid) {
        mirror.replaceRange(evt.text.join('\n'), evt.from, evt.to)
      }
    } finally {
      onChangeEnabled = true
    }
  }
  window.reset_textarea = function(skip){
    onChangeEnabled = false
    try {
      m.replaceRange('', {line: 0, ch: 0}, {line:m.lineCount(), ch:0})
      if (!skip) {
        Changes.remove({'filename':filename})
        Changes.insert({'filename':filename, uuid: uuid, date: new Date(), action: 'reset'})
      }
    } finally {
      onChangeEnabled = true
    }
  }
  var date = 0
  changes.forEach(function(ch) {
    date = Math.max(new Date(ch.date).getTime(), date)
    if (ch.action == 'reset') {
      window.reset_textarea()
    } else {
      exec(ch, m)
    }
  })

  if (date === 0) date = undefined;
  Changes.find({date: {$gt: new Date(date)}, 'filename':filename, uuid: {$ne: uuid}}).observe({
    added: function (ch) {
      if (uuid != ch.uuid && filename == ch.filename) {
        if (ch.action == 'reset') {
          window.reset_textarea(true)
        } else {
          exec(ch, m)
        }
      }
    }
  })
}`

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
