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
    return MeteoriteDocuments.find('filename': file) if file?
)

_.extend( Template.editor,
  content: -> @content
  events: {
    #editing
    'keydown #input': (event) ->
      if not event.isImmediatePropagationStopped()
        event.preventDefault()
        s = String.fromCharCode(event.which)
        unless event.shiftKey
          s = s.toLowerCase()
        @content = @content[..@carot.start-1]+s+@content[@carot.end..]
        @carot.start = @carot.end = @carot.start+1
        MeteoriteDocuments.update(@_id, @)
        Meteor.flush()
        event.stopImmediatePropagation()
    'mouseup textarea[name=\'editor\']': (event) ->
      if not event.isImmediatePropagationStopped()
        @carot = $(event.target).caret()
        $(event.target).blur()
        $('#input').focus()
        event.stopImmediatePropagation()
  }
)

_.extend( Template.file_list,
  files: ->
    results = MeteoriteDocuments.find( {}, { fields: {filename: 1} } ).fetch()
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
