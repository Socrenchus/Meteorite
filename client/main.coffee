# Collections
Changes = new Meteor.Collection("changes")
Files = new Meteor.Collection("files")

uuid = Meteor.uuid()
Session.set( 'current_files', [] )

# Subscriptions
Meteor.subscribe( 'code_filenames' )
Meteor.autosubscribe( ->
  Meteor.subscribe( 'code_file', Session.get( 'current_files' ) )
)

# Templates
##
_.extend( Template.file_list,
  files: ->
    return a.children for a in Files.find().fetch()
  events: {
    'click #delete': (event) ->
      file = $(event.target).parent().children('#file').html()
      Meteor.call( 'delete_file', root_path + file )
  }
)

_.extend( Template.dir,
  name: -> @name
  path: -> @path
  children: -> @children
  expanded: -> Session.get(@path)
  events: {
    'click #file': (event) ->
      if not event.isImmediatePropagationStopped()
        expanded = Session.get(@path)
        expanded ?= false
        Session.set(@path, !expanded)
        unless @children? and @children.length > 0
          Router.navigate('/edit/'+@path, trigger:true)
        event.stopImmediatePropagation()
  }
)

# Code editor

on_change_enabled = true
init = (filename, mimetype) ->
  editor = $('#editor')
  editor = editor.clone().attr('id', "#{filename.replace(/\//g,'s').replace(/\./g,'d')}").insertAfter(editor)
  ta = editor.children('#code')[0]
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
  on_key_event = (m, evt) ->
    switch evt.which
      when 9
        if evt.type is 'keyup'
          m.indentSelection()
      when 83
        if evt.metaKey or evt.ctrlKey
          evt.stop()
          Meteor.call('save_file_text', filename, m.getValue())
  CodeMirror.commands.none = (cm) ->    
  CodeMirror.commands.autocomplete = (cm) ->
    CodeMirror.simpleHint(cm, CodeMirror.javascriptHint)
  CodeMirror.modeURL = '/mode/%N/%N.js'
  m = CodeMirror.fromTextArea(ta,
    electricChars: false
    indentWithTabs: false
    indentUnit: 2
    smartIndent: false
    lineNumbers: true
    extraKeys: {
      "Ctrl-Space": "autocomplete"
      "Tab": 'none'
    }
    onChange: on_change
    onKeyEvent: on_key_event
  )
  m.focus()
  m.setSelection({line:0, ch:0}, {line:m.lineCount(), ch:0})

  switch mimetype.split('/')[0]
    when 'text'
      changes = Changes.find({'filename':filename}, {sort: {date: 1}})
  
      for n in CodeMirror.listMIMEs()
        if mimetype?
          m.setOption('mode', n.mode) if n.mime is mimetype
          
      reset = ->
        # reset editor
        on_change_enabled = false
        try
          m.replaceRange('', {line: 0, ch: 0}, {line:m.lineCount(), ch:0})
        finally
          on_change_enabled = true
      reset()
    
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
      m.clearHistory()
      editor.show()
    when 'image'
      tron.warn('Meteorite does not currently support images.')

# Backbone router
class Router extends Backbone.Router
  routes:
    "edit*path": "edit_file"

  edit_file: (path) ->
    files = Session.get( 'current_files')
    filename = root_path + path
    Session.set( 'current_files', [filename].concat(files))
    Meteor.call( 'get_mime_type', filename, (e, r) ->
      editor = $("##{filename.replace(/\//g,'s').replace(/\./g,'d')}")
      $('.editor').hide()
      if editor.length > 0
        editor.show()
      else
        init(filename, r)
    )

    

Router = new Router()
Meteor.startup( ->
  Backbone.history.start( pushState: true ) #!SUPPRESS no_headless_camel_case
)
