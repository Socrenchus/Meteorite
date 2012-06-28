MeteoriteDocuments = new Meteor.Collection("meteorite")

writeFile = (filename, content) ->
  __meteor_bootstrap__.require('fs').writeFile(filename, content, 'utf8', (err) ->
      if err
          tron.log(err)
  )

readFile = (filename) ->
  return __meteor_bootstrap__.require('fs').readFileSync(filename,'utf8')

deleteFile = (filename) ->
  __meteor_bootstrap__.require('fs').unlink(filename, (err) ->
    if (err)
      tron.error(err)
  )

class Meteorite
  constructor: (@method) ->
    @default =
      Meteor.default_server.method_handlers["/meteorite/#{@method}"]
    Meteor.default_server.method_handlers["/meteorite/#{@method}"] =
      @dispatch

  dispatch: (args...) =>
    delayedWriteFile = _.debounce(writeFile, 5000)
    switch @method
      when 'insert'
        delayedWriteFile( args[0].filename, args[0].content )
      when 'update'
        delayedWriteFile( args[1].filename, args[1].content )
      when 'remove'
        deleteFile( args[0].filename )

    @default.apply(@, args)

Meteor.publish('code_file', (filename) ->
  return MeteoriteDocuments.find( 'filename': filename )
)

Meteor.publish('code_filenames', ->
  return MeteoriteDocuments.find( {}, { fields: {filename: 1} } )
)

Meteor.startup( ->
  for method in ['insert','update','remove']
    m = new Meteorite(method)
)