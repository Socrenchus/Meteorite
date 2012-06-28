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
    filename = ''
    switch @method
      when 'insert'
        filename = args[0].filename
      when 'update'
        filename = args[1].filename
      when 'remove'
        filename = args[0].filename

    if filename?
      file_text = (a.text for a in MeteoriteDocuments.find( 'filename': filename ).fetch()).join('\n')
      delayedWriteFile( filename, file_text )

    @default.apply(@, args)

Meteor.publish('code_file', (filename) ->
  return MeteoriteDocuments.find( 'filename': filename )
)

Meteor.publish('code_filenames', ->
  return MeteoriteDocuments.find( {number: 0}, { fields: {filename: 1} } )
)

Meteor.startup( ->
  for method in ['insert','update','remove']
    m = new Meteorite(method)
)