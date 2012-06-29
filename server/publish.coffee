Changes = new Meteor.Collection("changes")

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

Meteor.publish('code_file', (filename) ->
  return Changes.find( 'filename': filename )
)

Meteor.publish('code_filenames', ->
  return Changes.find( {}, { fields: {filename: 1} } )
)

Meteor.methods(
  save_file_text: (filename, text) ->
    delayedWriteFile = _.throttle(writeFile, 2000)
    delayedWriteFile( filename, text )
)