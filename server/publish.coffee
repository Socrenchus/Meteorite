Changes = new Meteor.Collection("changes")

writeFile = (filename, content) ->
  __meteor_bootstrap__.require('fs').writeFile(filename, content, 'utf8', (err) ->
      if err
          tron.log(err)
  )

delayedWriteFile = _.throttle(writeFile, 2000)

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
  uuid = Meteor.uuid()
  uniq = {}
  
  Changes.find( {}, { fields: {filename: 1} } ).observe(
    added: (doc, idx) =>
      #@set("changes", uuid, )
      #@flush()
  )
)

Meteor.methods(
  save_file_text: (filename, text) ->
    delayedWriteFile( filename, text )
  get_mime_type: (filename) ->
    custom =
      'coffee':'text/x-coffeescript'
      'styl':'text/css'
    extension = filename[filename.lastIndexOf('.')+1..]
    if extension of custom
      return custom[extension]
    else
      mime = __meteor_bootstrap__.require('mime')
      return mime.lookup(filename)
)