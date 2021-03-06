_   = require('lodash')
DOM = require('./dom')


ieVersion = do ->
  matchVersion = navigator.userAgent.match(/MSIE [0-9\.]+/)
  return if matchVersion? then parseInt(matchVersion[0].slice("MSIE".length)) else null


Utils =
  BLOCK_TAGS: [
    'ADDRESS'
    'BLOCKQUOTE'
    'DD'
    'DIV'
    'DL'
    'H1', 'H2', 'H3', 'H4', 'H5', 'H6'
    'LI'
    'OL'
    'P'
    'PRE'
    'TABLE'
    'TBODY'
    'TD'
    'TFOOT'
    'TH'
    'THEAD'
    'TR'
    'UL'
  ]

  findAncestor: (node, checkFn) ->
    while node? && !checkFn(node)
      node = node.parentNode
    return node

  findClosestPoint: (point, list, prepFn = ->) ->    # Using Euclidean distance
    point = prepFn.call(null, point)
    point = [point] if !_.isArray(point)
    closestDist = Infinity
    closestValue = false
    for key,coords of list
      coords = prepFn.call(null, coords)
      coords = [coords] if !_.isArray(coords)
      dist = _.reduce(coords, (dist, coord, i) ->
        dist + Math.pow(coord - point[i], 2)
      , 0)
      dist = Math.sqrt(dist)
      return key if dist == 0
      if dist < closestDist
        closestDist = dist
        closestValue = key
    return closestValue

  findDeepestNode: (node, offset) ->
    if node.firstChild?
      for child in DOM.getChildNodes(node)
        length = Utils.getNodeLength(child)
        if offset < length
          return Utils.findDeepestNode(child, offset)
        else
          offset -= length
      return Utils.findDeepestNode(child, offset + length)
    else
      return [node, offset]

  getChildAtOffset: (node, offset) ->
    child = node.firstChild
    length = Utils.getNodeLength(child)
    while child?
      break if offset < length
      offset -= length
      child = child.nextSibling
      length = Utils.getNodeLength(child)
    unless child?
      child = node.lastChild
      offset = Utils.getNodeLength(child)
    return [child, offset]

  getNodeLength: (node) ->
    return 0 unless node?
    if node.nodeType == DOM.ELEMENT_NODE
      return _.reduce(DOM.getChildNodes(node), (length, child) ->
        return length + Utils.getNodeLength(child)
      , if Utils.isLineNode(node) then 1 else 0)
    else if node.nodeType == DOM.TEXT_NODE
      return DOM.getText(node).length
    else
      return 0

  isBlock: (node) ->
    return _.indexOf(Utils.BLOCK_TAGS, node.tagName, true) > -1

  isEmptyDoc: (root) ->
    firstLine = root.firstChild
    return true if firstLine == null
    return true if firstLine.firstChild == null
    return true if firstLine.firstChild == firstLine.lastChild and firstLine.firstChild.tagName == 'BR'
    return false

  # We'll take a leap of faith that IE11 is good enough...
  isIE: (maxVersion = 10) ->
    return ieVersion? and maxVersion >= ieVersion

  isLineNode: (node) ->
    return node?.parentNode? and DOM.hasClass(node.parentNode, 'editor-container') and Utils.isBlock(node)

  partitionChildren: (node, offset, length) ->
    [prevNode, startNode] = Utils.splitChild(node, offset)
    [endNode, nextNode] = Utils.splitChild(node, offset + length)
    return [startNode, endNode]

  # Firefox needs splitBefore, not splitAfter like it used to be, see doc/selection
  splitBefore: (node, root) ->
    return false if node == root or node.parentNode == root
    parentNode = node.parentNode
    parentClone = parentNode.cloneNode(false)
    parentNode.parentNode.insertBefore(parentClone, parentNode)
    while node.previousSibling?
      parentClone.insertBefore(node.previousSibling, parentClone.firstChild)
    Utils.splitBefore(parentNode, root)

  splitChild: (parent, offset) ->
    [node, offset] = Utils.getChildAtOffset(parent, offset)
    return Utils.splitNode(node, offset)

  splitNode: (node, offset, force = false) ->
    # Check if split necessary
    nodeLength = Utils.getNodeLength(node)
    offset = Math.max(0, offset)
    offset = Math.min(offset, nodeLength)
    return [node.previousSibling, node, false] unless force or offset != 0
    return [node, node.nextSibling, false] unless force or offset != nodeLength
    if node.nodeType == DOM.TEXT_NODE
      after = node.splitText(offset)
      return [node, after, true]
    else
      left = node
      right = node.cloneNode(false)
      node.parentNode.insertBefore(right, left.nextSibling)
      [child, offset] = Utils.getChildAtOffset(node, offset)
      [childLeft, childRight] = Utils.splitNode(child, offset)
      while childRight != null
        nextRight = childRight.nextSibling
        right.appendChild(childRight)
        childRight = nextRight
      return [left, right, true]

  traversePostorder: (root, fn, context = fn) ->
    return unless root?
    cur = root.firstChild
    while cur?
      Utils.traversePostorder.call(context, cur, fn)
      cur = fn.call(context, cur)
      cur = cur.nextSibling if cur?

  traversePreorder: (root, offset, fn, context = fn, args...) ->
    return unless root?
    cur = root.firstChild
    while cur?
      nextOffset = offset + Utils.getNodeLength(cur)
      curHtml = cur.innerHTML
      cur = fn.call(context, cur, offset, args...)
      Utils.traversePreorder.call(null, cur, offset, fn, context, args...)
      if cur? && cur.innerHTML == curHtml
        cur = cur.nextSibling
        offset = nextOffset


module.exports = Utils
