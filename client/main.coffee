# Collections
Changes = new Meteor.Collection("changes")
Files = new Meteor.Collection("files")

uuid = Meteor.uuid()

# Subscriptions
Meteor.subscribe( 'code_filenames' )
Meteor.autosubscribe( ->
  Meteor.subscribe( 'code_file', root_path + Session.get( 'current_file' ) )
)

# Templates
##
_.extend( Template.file_list,
  show: -> true
  files: ->
    return Files.find()
)

# Code editor

filename = ''
mimetype = null
m = ''
on_change_enabled = true
ta = null
init = ->
  ta = document.getElementById("code")
  on_change = (m, evt) ->
    #tron.log('on_change:', m, evt)
    while evt
      Changes.insert(
        filename: filename
        uuid: uuid
        date: new Date()
        text: evt.text
        from: evt.from
        to: evt.to
      ) if on_change_enabled
      evt = evt.next
  CodeMirror.commands.autocomplete = (cm) ->
    CodeMirror.simpleHint(cm, CodeMirror.javascriptHint)
  CodeMirror.commands.open_file = (cm) ->
    window.location = '/'
  CodeMirror.commands.save_file = (cm) ->
    Meteor.call('save_file_text', filename, m.getValue())
  CodeMirror.modeURL = '/mode/%N/%N.js'
  m = CodeMirror.fromTextArea(ta,
    electricChars: false
    indentWithTabs: false
    tabSize: 2
    smartIndent: true
    lineNumbers: true
    autoFocus: true
    extraKeys: {
      "Ctrl-Space": "autocomplete"
      "Esc": "open_file"
      "Shift-Enter": "save_file"
    }
    onChange: on_change
  )
  m.focus()
  m.setSelection({line:0, ch:0}, {line:m.lineCount(), ch:0})

reload = ->
  changes = Changes.find({'filename':filename}, {sort: {date: 1}})
  
  for n in CodeMirror.listMIMEs()
    if mimetype?
      m.setOption('mode', n.mode) if n.mime is mimetype
    
  # execute the modification on the mirror
  exec = (evt, mirror) ->
    on_change_enabled = false
    try
      if (evt.uuid != uuid)
        mirror.replaceRange(evt.text.join('\n'), evt.from, evt.to)
    finally
      on_change_enabled = true

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
    "delete*path": "delete_file"
    "run/:branchname": "run_branch"

  edit_file: (path) ->
    Session.set( 'current_file', path )
    filename = root_path + path
    Meteor.call( 'get_mime_type', filename, (e, r) -> 
      mimetype = r
      _.once( init )()
      reload()
      $('#filelist').hide()
      $('#editor').show()
    )
  
  delete_file: (path) ->
    Meteor.call( 'delete_file', root_path + path )

    

Router = new Router()
Meteor.startup( ->
  Backbone.history.start( pushState: true ) #!SUPPRESS no_headless_camel_case
)
