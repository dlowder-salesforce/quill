_        = require('lodash')
rangy    = require('rangy-core')
DOM      = require('./dom')
Position = require('./position')
Range    = require('./range')
Utils    = require('./utils')


compareNativeRanges = (r1, r2) ->
  return true if r1 == r2           # Covers both is null case
  return false unless r1? and r2?   # If either is null they are not equal
  return r1.equals(r2)

# DOM Selection API says offset is child index of container, not number of characters like Position
normalizeNativePosition = (node, offset) ->
  if node?.nodeType == DOM.ELEMENT_NODE
    return [node, 0] unless node.firstChild?
    offset = Math.min(node.childNodes.length, offset)
    if offset < node.childNodes.length
      return normalizeNativePosition(node.childNodes[offset], 0)
    else
      if node.lastChild.nodeType == DOM.ELEMENT_NODE
        return normalizeNativePosition(node.lastChild, node.lastChild.childNodes.length)
      else
        return [node.lastChild, Utils.getNodeLength(node.lastChild)]
  return [node, offset]

normalizeNativeRange = (nativeRange) ->
  return null unless nativeRange?
  [startContainer, startOffset] = normalizeNativePosition(nativeRange.startContainer, nativeRange.startOffset)
  [endContainer, endOffset] = normalizeNativePosition(nativeRange.endContainer, nativeRange.endOffset)
  return {
    startContainer  : startContainer
    startOffset     : startOffset
    endContainer    : endContainer
    endOffset       : endOffset
    isBackwards     : nativeRange.isBackwards
  }

_nativeRangeToRange = (nativeRange) ->
  return null unless nativeRange?
  start = new Position(@editor.doc, nativeRange.startContainer, nativeRange.startOffset)
  end = new Position(@editor.doc, nativeRange.endContainer, nativeRange.endOffset)
  if start.index <= end.index
    range = new Range(@editor.doc, start, end)
    range.isBackwards = false
  else
    range = new Range(@editor.doc, end, start)
    range.isBackwards = true
  range.isBackwards = true if nativeRange.isBackwards
  return range

_preserveWithIndex = (nativeRange, index, lengthAdded, fn) ->
  range = _nativeRangeToRange.call(this, nativeRange)
  [startIndex, endIndex] = _.map([range.start, range.end], (pos) ->
    if index >= pos.index
      return pos.index
    else
      return Math.max(pos.index + lengthAdded, index)
  )
  fn.call(null)
  this.setRange(new Range(@editor.doc, startIndex, endIndex), true)

_preserveWithLine = (savedNativeRange, fn) ->
  savedData = _.map([
    { container: savedNativeRange.startContainer, offset: savedNativeRange.startOffset }
    { container: savedNativeRange.endContainer,   offset: savedNativeRange.endOffset }
  ], (position) =>
    lineNode = Utils.findAncestor(position.container, Utils.isLineNode) or @editor.root
    return {
      lineNode  : lineNode
      offset    : Position.getIndex(position.container, position.offset, lineNode)
      nextLine  : position.container.previousSibling?.tagName == 'BR'  # Track special case for Firefox
    }
  )
  fn.call(null)
  nativeRange = this.getNativeRange(true)
  if !_.isEqual(nativeRange, savedNativeRange)
    [start, end] = _.map(savedData, (savedDatum) =>
      if savedDatum.nextLine and savedDatum.lineNode.nextSibling?
        savedDatum.lineNode = savedDatum.lineNode.nextSibling
        savedDatum.offset = 0
      return new Position(@editor.doc, savedDatum.lineNode, savedDatum.offset)
    )
    this.setRange(new Range(@editor.doc, start, end), true)

_updateFocus = (silent) ->
  hasFocus = @editor.renderer.checkFocus()
  if !silent and @hasFocus != hasFocus
    if hasFocus
      if @blurTimer
        clearTimeout(@blurTimer)
        @blurTimer = null
      else
        @emitter.emit(@emitter.constructor.events.FOCUS_CHANGE, true)
    else if !@blurTimer?
      @blurTimer = setTimeout( =>
        @emitter.emit(@emitter.constructor.events.FOCUS_CHANGE, false)  if @hasFocus == false
        @blurTimer = null
      , 200)
  @hasFocus = hasFocus


class Selection
  constructor: (@editor, @emitter) ->
    @range = null
    @blurTimer = null
    rangy.init()
    if @editor.renderer.options.iframe
      @nativeSelection = rangy.getIframeSelection(@editor.renderer.iframe) if @editor.renderer.iframe.parentNode?
    else
      @nativeSelection = rangy.getSelection()
    this.setRange(null, true)
    @hasFocus = @editor.renderer.checkFocus()
    DOM.addEventListener(@editor.root, 'focus', =>
      _.defer( => @editor.checkUpdate())
    )
    DOM.addEventListener(@editor.root, 'beforedeactivate blur mouseup', =>
      @editor.checkUpdate()
    )

  getDimensions: ->
    return null unless @range?
    nativeRange = @range.nativeRange or @range.textRange
    return nativeRange.getBoundingClientRect()

  getNativeRange: (normalize = false) ->
    return @range unless @editor.renderer.checkFocus()
    return null unless @nativeSelection
    @nativeSelection.refresh()
    range = if @nativeSelection?.rangeCount > 0 then @nativeSelection.getRangeAt(0) else null
    # Selection elements needs to be within editor root
    range = null if range? and (!rangy.dom.isAncestorOf(@editor.root, range.startContainer, true) or !rangy.dom.isAncestorOf(@editor.root, range.endContainer, true))
    if range
      range = normalizeNativeRange(range) if normalize
      range.isBackwards = true if @nativeSelection.isBackwards()
      return range
    else
      return null

  getRange: ->
    nativeRange = this.getNativeRange(true)
    return if nativeRange? then _nativeRangeToRange.call(this, nativeRange) else null

  preserve: (index, lengthAdded, fn) ->
    fn = index if _.isFunction(index)
    nativeRange = this.getNativeRange(true)
    if @range?
      if _.isFunction(index)
        _preserveWithLine.call(this, nativeRange, index)
      else
        _preserveWithIndex.call(this, nativeRange, index, lengthAdded, fn)
    else
      fn.call(null)

  setRange: (range, silent = false) ->
    return unless @nativeSelection?
    @nativeSelection.removeAllRanges() if @editor.renderer.checkFocus()
    if range?
      nativeRange = rangy.createRangyRange(@editor.renderer.getDocument())
      _.each([range.start, range.end], (pos, i) ->
        [node, offset] = Utils.findDeepestNode(pos.leafNode, pos.offset)
        offset = Math.min(DOM.getText(node).length, offset)   # Should only occur at end of document
        if node.tagName == 'BR'             # Firefox does not split BR, IE cannot select BR
          node = node.parentNode
          offset = 1 if Utils.isIE()
        fn = if i == 0 then 'setStart' else 'setEnd'
        nativeRange[fn].call(nativeRange, node, offset)
      )
      @nativeSelection.addRange(nativeRange, range.isBackwards)
      @range = nativeRange
    else
      @range = null
    @emitter.emit(@emitter.constructor.events.SELECTION_CHANGE, range) unless silent

  update: (silent = false) ->
    _updateFocus.call(this, silent)
    if @hasFocus
      nativeRange = this.getNativeRange(false)
      return if compareNativeRanges(nativeRange, @range)
      @range = nativeRange
      range = _nativeRangeToRange.call(this, normalizeNativeRange(@range))
      if Utils.isEmptyDoc(@editor.root)
        this.setRange(range, silent)
      else
        @emitter.emit(@emitter.constructor.events.SELECTION_CHANGE, range) unless silent


module.exports = Selection
