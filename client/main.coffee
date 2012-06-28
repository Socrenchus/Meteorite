# Collections
MeteoriteDocuments = new Meteor.Collection("meteorite")

Session.set( 'current_file', '/client/html/templates/group.html ' )

# Subscriptions
Meteor.subscribe( 'code_filenames' )
Meteor.autosubscribe( ->
  Meteor.subscribe( 'code_file', root_path + Session.get( 'current_file' ) )
)

# Templates
_.extend( Template.editors,
  editors: ->
    file = Session.get( 'current_file' )
    file = root_path + file if file?
    return MeteoriteDocuments.find('filename': file, {'sort': {'number':1}}) if file?
)

_.extend( Template.editor,
  text: -> @text
  number: -> @number
  events: {
    #editing
    'keydown textarea': (event) ->
      if event.keyIdentifier in ['Up', 'Down', 'Enter']
          event.preventDefault()
    'keyup textarea': (event) ->
      if not event.isImmediatePropagationStopped()
        
        shift_lines = (start, ammount) =>
          rest = MeteoriteDocuments.find({'filename': @filename, 'number':{'$gt':start}}, {'sort': {'number':1}}).fetch()
          for d in rest
            d.number += ammount
            MeteoriteDocuments.update(d._id, d)

        switch event.keyIdentifier
          when 'Up'
            pos = $(event.target).caret().start
            current = $(event.target).blur()
            prev = current.prev().caret(pos,pos)
          when 'Down'
            pos = $(event.target).caret().start
            current = $(event.target).blur()
            next = current.next().caret(pos,pos)
          when 'Left'
            caret = $(event.target).caret()
            if caret.start == 0
              $(event.target).prev().caret(100,100)
          when 'Right'
            caret = $(event.target).caret()
            unless caret.end < @text.length
              $(event.target).next().caret(0,0)
          when 'Enter'
            caret = $(event.target).caret()
            $(event.target).blur()
            shift_lines(@number, 1)
            MeteoriteDocuments.insert({'filename': @filename, 'number':@number+1, 'text':@text[caret.end..]})
            @text = @text[..caret.start-1]
            MeteoriteDocuments.update(@_id, @)
            Meteor.flush()
            $(event.target).next().caret(0,0)
          when 'U+0008'
            caret = $(event.target).unbind().caret()
            if caret.start == 0
              prev = MeteoriteDocuments.findOne({'filename': @filename, 'number':@number-1})
              prev.text += @text[caret.end-1..]
              $(event.target).prev().caret(prev.text.length,prev.text.length)
              MeteoriteDocuments.update(prev._id, prev)
              MeteoriteDocuments.remove(@_id)
              shift_lines(@number, -1)
              Meteor.flush()
          else
            @text = event.target.value
            MeteoriteDocuments.update(@_id, @)
            Meteor.flush()
        event.stopImmediatePropagation()
  }
)

_.extend( Template.file_list,
  files: ->
    results = MeteoriteDocuments.find( {}, { fields: {filename: 1} } ).fetch()
    dedup = {}
    return ( {filename: r.filename[root_path.length+1..]} for r in results )
)

# Backbone router
class Router extends Backbone.Router
  routes:
    "edit*path": "edit_file"
    "run/:branchname": "run_branch"

  edit_file: (path) ->
    Session.set( 'current_file', path )

Router = new Router()
Meteor.startup( ->
  Backbone.history.start( pushState: true ) #!SUPPRESS no_headless_camel_case
)
