# IE feature detection
supportsRGBA = true
scriptElem = document.getElementsByTagName('script')[0]
try
  scriptElem.style.color = 'rgba(128,128,128,0.5)'
catch e
  supportsRGBA = false
finally
  scriptElem.style.color = ""


getColor = (id, lighten) ->
  alpha = if lighten then '0.4' else '1.0'
  if id == 1 or id == 'quill-1'
    return if supportsRGBA then "rgba(0,153,255,#{alpha})" else "rgb(0,153,255)"
  else
    return if supportsRGBA then "rgba(255,153,51,#{alpha})" else "rgb(255,153,51)"

listenEditor = (source, target) ->
  source.on(Quill.events.TEXT_CHANGE, (delta, origin) ->
    return if origin == 'api'
    target.updateContents(delta)
    sourceDelta = source.getContents()
    targetDelta = target.getContents()
    decomposeDelta = targetDelta.decompose(sourceDelta)
    isEqual = _.all(decomposeDelta.ops, (op) ->
      return false if op.delta?
      return true if (_.keys(op.attributes).length == 0)
      sourceOp = sourceDelta.getOpsAt(op.start, op.end - op.start)
      return true if sourceOp.length == 1 and sourceOp[0].delta == "\n"
      return false
    )
    console.assert(decomposeDelta.startLength == decomposeDelta.endLength and isEqual, "Editor diversion!", source, target, sourceDelta, targetDelta) if console?
  ).on(Quill.events.SELECTION_CHANGE, (range) ->
    return unless range?
    target.getModule('multi-cursor').moveCursor(source.id, range.end.index)
  )


editors = []
for num in [1, 2]
  $wrapper = $(".editor-wrapper.#{if num == 1 then 'first' else 'last'}")
  $container = $('.editor-container', $wrapper)
  editor = new Quill($container.get(0), {
    modules:
      'multi-cursor': true
      'toolbar': {
        container: $('.toolbar-container', $wrapper).get(0)
      }
    theme: 'snow'
  })
  authorship = editor.addModule('authorship', {
    authorId: editor.id
    color: getColor(num, true)
    button: $('.sc-authorship', $wrapper).get(0)
  })
  editors.push(editor)

listenEditor(editors[0], editors[1])
listenEditor(editors[1], editors[0])
editors[0].getModule('authorship').addAuthor(editors[1].id, getColor(editors[1].id, true))
editors[1].getModule('authorship').addAuthor(editors[0].id, getColor(editors[0].id, true))
editors[0].getModule('multi-cursor').setCursor(editors[1].id, 0, editors[1].id, getColor(editors[1].id))
editors[1].getModule('multi-cursor').setCursor(editors[0].id, 0, editors[0].id, getColor(editors[0].id))
