# Collections
Changes = new Meteor.Collection("changes")
Files = new Meteor.Collection("files")

uuid = Meteor.uuid()
Session.set( 'current_files', [] )

# Subscriptions
Meteor.subscribe( 'code_filenames' )

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
  chars_to_rewrite = 0
  on_change = (m, evt) ->
    #tron.log('on_change:', m, evt)
    while evt
      obj =
        filename: filename
        uuid: uuid
        date: new Date()
        text: evt.text
        from: evt.from
        to: evt.to
      contents = m.getValue().split('\n')
      if chars_to_rewrite <= 0
        last_line = m.lineCount()-1
        last_ch = contents[last_line].length
        obj.text = contents
        obj.from = {line:0, ch:0}
        obj.to = {line:last_line, ch:last_ch}
        obj.rewrite = true
        chars_to_rewrite = m.getValue().length
      else
        changed = contents[evt.from.line...evt.to.line].join('').length
        changed -= (evt.from.ch - evt.to.ch)
        changed ||= 1
        chars_to_rewrite -= 2 * changed
      Changes.insert( obj ) if on_change_enabled
      evt = evt.next
  on_key_event = (m, evt) ->
    switch evt.which
      when 83 # 's' key
        if evt.metaKey or evt.ctrlKey
          evt.stop()
          Meteor.call('save_file_text', filename, m.getValue())
  CodeMirror.commands.indent = (cm) -> cm.indentSelection()
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
      "Tab": 'indent'
    }
    onChange: on_change
    onKeyEvent: on_key_event
  )
  m.focus()
  m.setSelection({line:0, ch:0}, {line:m.lineCount(), ch:0})

  switch mimetype.split('/')[0]
    when 'text'
      last_rewrite = Changes.findOne({'filename':filename,'rewrite':true}, {sort: {date: -1}})
      last_rewrite = last_rewrite.date
      changes = Changes.find({'filename':filename,'date':{'$gte':last_rewrite}}, {sort: {date: 1}}).fetch()
      
      for n in CodeMirror.listMIMEs()
        if mimetype?
          m.setOption('mode', n.mode) if n.mime is mimetype
    
      # execute the modification on the mirror
      exec = (evt, mirror) ->
        on_change_enabled = false
        try
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
      m.refresh()
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
        Meteor.subscribe( 'code_file', filename, ->
          init(filename, r)
        )
    )

Router = new Router()
Meteor.startup( ->
  Backbone.history.start( pushState: true ) #!SUPPRESS no_headless_camel_case
)
