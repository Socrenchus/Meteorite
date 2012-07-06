
fs = __meteor_bootstrap__.require("fs")
  
walk = (dir) ->
  results = []
  list = fs.readdirSync( dir )
  pending = list.length
  return results unless pending
  for file in list
    file = dir + "/" + file
    stat = fs.statSync( file )
    if stat?.isDirectory()
      results = results.concat( walk( file ) )
    else
      results.push file
  return results

Meteor.startup( ->  
  if Changes.find().count() is 0
    files = walk(root_path)
    for file in files
      hidden = false
      for a in file.split('/')
        hidden ||= (a[0] == '.' && a[1] != '.')
      mimetype = Meteor.call('get_mime_type', file)
      hidden ||= not (mimetype.split('/')[0] is 'text')
      content = readFile(file).split('\n')
      Changes.insert(
        filename: file
        uuid: Meteor.uuid()
        date: new Date()
        text: content
        from: {ch: 0, line: 0}
        to: {ch: 0, line: 0}
        rewrite: true
      ) unless hidden
    
)