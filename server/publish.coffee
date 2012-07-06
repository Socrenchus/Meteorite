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
  return Changes.find( {'filename': filename} )
)

Meteor.publish('code_filenames', ->
  files =
    name: 'root'
    children: []
  uuid = Meteor.uuid()
  
  build_obj = (prev, cur, next, siblings) ->
    sibs = siblings
    sibs ?= []
    result = []
    
    for s in sibs
      if cur is s.name
        children = s.children
      else
        result.push( s )
    children ?= []
    new_prev = prev
    new_prev.push(cur)
    new_cur = next[0]
    new_next = next[1..]
    tron.test( ->
      return
      tron.log 'prev:',prev,new_prev
      tron.log 'cur:', cur, new_cur
      tron.log 'next:', next, new_next
      tron.log 'children:', siblings,children
    )
    result.push(
      path: new_prev.join('/')
      name: cur
      children: build_obj(new_prev, new_cur, new_next, children) if new_cur?.length > 0
    )
    return result
  
  handle = Changes.find( {}, { fields: {filename: 1} } ).observe(
    added: (doc, idx) =>
      p = doc.filename[root_path.length..]
      p = p.split('/')[1..]
      files.children = build_obj([], p[0], p[1..], files.children)
      @set('files', uuid, files)
      @flush()
    removed: (doc, idx) =>
      @rewind()
      @flush()
  )
  
  @onStop = =>
    handle.stop()
    @unset( 'files', uuid, ['files'] )
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
  delete_file: (filename) ->
    deleteFile(filename)
    for file in Changes.find(filename: filename).fetch()
      Changes.remove(file._id)
)