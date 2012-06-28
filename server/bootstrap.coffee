
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
  if MeteoriteDocuments.find().count() is 0
    files = walk(root_path)
    for file in files
      hidden = false
      for a in file.split('/')
        hidden ||= (a[0] == '.' && a[1] != '.')
      MeteoriteDocuments.insert(
        filename: file
        content: readFile(file)
      ) unless hidden
    
)