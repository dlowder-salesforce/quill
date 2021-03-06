_     = require('lodash')
_.str = require('underscore.string')
DOM   = require('./dom')
Utils = require('./utils')


class LeafFormat
  constructor: (@root, @keyName) ->

  clean: (node) ->
    DOM.clearAttributes(node)
    return node

  createContainer: ->
    throw new Error("Descendants should implement")

  matchContainer: (container) ->
    throw new Error("Descendants should implement")

  preformat: (value) ->
    throw new Error("Descendants should implement")


class TagFormat extends LeafFormat
  constructor: (@root, @keyName, @tagName) ->
    super

  approximate: (value) ->
    throw new Error('Tag format must have truthy value') unless value
    return true

  clean: (node) ->
    node = super(node)
    node = DOM.switchTag(node, @tagName) unless node.tagName == @tagName
    return node

  createContainer: ->
    return @root.ownerDocument.createElement(@tagName)

  matchContainer: (container) ->
    return container.tagName == @tagName

  preformat: (value) ->
    @root.ownerDocument.execCommand(@keyName, false, value)


class SpanFormat extends TagFormat
  constructor: (@root, @keyName) ->
    super(@root, @keyName, 'SPAN')

  clean: (node) ->
    # cannot super because LeafFormat removes all attributes
    node = DOM.switchTag(node, @tagName) unless node.tagName == @tagName
    return node

  approximate: (value) ->
    throw new Error("Descendants should implement")


class ClassFormat extends SpanFormat
  constructor: (@root, @keyName) ->
    super

  approximate: (value) ->
    parts = value.split('-')
    if parts.length > 1 and parts[0] == @keyName
      return parts.slice(1).join('-')
    return false

  clean: (node) ->
    DOM.clearAttributes(node, 'class')
    return node

  createContainer: (value) ->
    container = super(value)
    DOM.addClass(container, "#{@keyName}-#{value}")
    return container

  matchContainer: (container) ->
    if super(container)
      classList = DOM.getClasses(container)
      for css in classList
        value = this.approximate(css)
        return value if value
    return false


class StyleFormat extends SpanFormat
  @getStyleObject: (container) ->
    # Iterating through container.style upsets IE8
    styleString = container.getAttribute('style') or ''
    obj = _.reduce(styleString.split(';'), (styles, str) ->
      [name, value] = str.split(':')
      if name and value
        name = _.str.trim(name)
        value = _.str.trim(value)
        styles[name.toLowerCase()] = value
      return styles
    , {})
    return obj

  constructor: (@root, @keyName, @cssName, @defaultStyle, @styles) ->
    super

  approximate: (cssValue) ->
    for key,value of @styles
      if value.toUpperCase() == cssValue.toUpperCase()
        return if key == @defaultStyle then false else key
    return false

  clean: (node) ->
    node = super(node)
    styleObj = StyleFormat.getStyleObject(node)
    DOM.clearAttributes(node, 'style')
    if styleObj[@cssName]
      style = this.approximate(styleObj[@cssName])
      node.setAttribute('style', "#{@cssName}: #{@styles[style]};") if style    # PhantomJS adds a trailing space if we use node.style
    return node

  createContainer: (value) ->
    container = super(value)
    cssName = _.str.camelize(@cssName)
    style = this.approximate(value)
    container.setAttribute('style', "#{@cssName}: #{@styles[style]};") if style # PhantomJS adds a trailing space if we use node.style
    return container

  matchContainer: (container) ->
    style = container.style?[_.str.camelize(@cssName)]
    return if style then this.approximate(style) else false

  preformat: (value) ->
    value = this.approximate(value) or @defaultStyle
    @root.ownerDocument.execCommand(_.str.camelize(@keyName), false, @styles[value])


class BoldFormat extends TagFormat
  constructor: (@root) ->
    super(@root, 'bold', 'B')

  matchContainer: (container) ->
    return super(container) or container.style?.fontWeight == 'bold'


class ItalicFormat extends TagFormat
  constructor: (@root) ->
    super(@root, 'italic', 'I')

  matchContainer: (container) ->
    return super(container) or container.style?.fontStyle == 'italic'


class StrikeFormat extends TagFormat
  constructor: (@root) ->
    super(@root, 'strike', 'S')

  matchContainer: (container) ->
    return super(container) or container.style?.textDecoration == 'line-through'

  preformat: (value) ->
    @root.ownerDocument.execCommand('strikeThrough', false, value)


class UnderlineFormat extends TagFormat
  constructor: (@root) ->
    super(@root, 'underline', 'U')

  matchContainer: (container) ->
    return super(container) or container.style?.textDecoration == 'underline'


class LinkFormat extends TagFormat
  constructor: (@root) ->
    super(@root, 'link', 'A')

  approximate: (value) ->
    value = 'http://' + value unless value.match(/^https?:\/\//)
    return value

  clean: (node) ->
    DOM.clearAttributes(node, ['href', 'title'])
    return node

  createContainer: (value) ->
    link = super(value)
    link.href = this.approximate(value)
    link.title = link.href
    return link

  matchContainer: (container) ->
    return if super(container) then container.getAttribute('href') else false


class ColorFormat extends StyleFormat
  @COLORS:
    'black'   : 'rgb(0, 0, 0)'
    'red'     : 'rgb(255, 0, 0)'
    'blue'    : 'rgb(0, 0, 255)'
    'lime'    : 'rgb(0, 255, 0)'
    'teal'    : 'rgb(0, 255, 255)'
    'magenta' : 'rgb(255, 0, 255)'
    'yellow'  : 'rgb(255, 255, 0)'
    'white'   : 'rgb(255, 255, 255)'

  @normalizeColor: (value) ->
    value = value.replace(/\ /g, '')
    if value[0] == '#' and value.length == 4
      return _.map(value.slice(1), (letter) ->
        parseInt(letter + letter, 16)
      )
    else if value[0] == '#' and value.length == 7
      return [
        parseInt(value.slice(1,3), 16)
        parseInt(value.slice(3,5), 16)
        parseInt(value.slice(5,7), 16)
      ]
    else if value.indexOf('rgb') == 0
      colors = value.slice(value.indexOf('(') + 1, value.indexOf(')')).split(',')
      return _.map(colors, (color) ->
        parseInt(color)
      )
    else
      return [0,0,0]

  constructor: (@root, @keyName, @cssName, @defaultStyle, @styles) ->
    super

  approximate: (value) ->
    return false unless value
    return value if @styles[value]?
    color = Utils.findClosestPoint(value, @styles, ColorFormat.normalizeColor)
    return if color == @defaultStyle then false else color


class BackColorFormat extends ColorFormat
  constructor: (@root) ->
    super(@root, 'back-color', 'background-color', 'white', ColorFormat.COLORS)


class FontNameFormat extends StyleFormat
  @normalizeFont: (fontStr) ->
    return _.map(fontStr.toUpperCase().split(','), (font) ->
      return _.str.trim(font, "'\" ")
    )

  constructor: (@root) ->
    super(@root, 'font-name', 'font-family', 'sans-serif', {
      'sans-serif': "'Helvetica', 'Arial', sans-serif"
      'serif'     : "'Times New Roman', serif"
      'monospace' : "'Courier New', monospace"
    })

  approximate: (value) ->
    values = FontNameFormat.normalizeFont(value)
    for key,fonts of @styles
      fonts = FontNameFormat.normalizeFont(fonts)
      return key if _.intersection(fonts, values).length > 0
    return false


class FontSizeFormat extends StyleFormat
  @SCALE: 6.75      # Conversion from execCommand size to px

  constructor: (@root) ->
    super(@root, 'font-size', 'font-size', 'normal', {
      'huge'  : '32px'
      'large' : '18px'
      'normal': '13px'
      'small' : '10px'
    })

  approximate: (value) ->
    return value if @styles[value]?
    if _.isString(value) and value.indexOf('px') > -1
      value = parseInt(value)
    else
      value = parseInt(value) * FontSizeFormat.SCALE
    size = Utils.findClosestPoint(value, @styles, parseInt)
    return if size == @defaultStyle then false else size

  preformat: (value) ->
    value = this.approximate(value) or @defaultStyle
    size = Math.round(parseInt(@styles[value]) / FontSizeFormat.SCALE)
    @root.ownerDocument.execCommand(_.str.camelize(@keyName), false, size)


class ForeColorFormat extends ColorFormat
  constructor: (@root) ->
    super(@root, 'fore-color', 'color', 'black', ColorFormat.COLORS)


module.exports =
  Leaf  : LeafFormat
  Tag   : TagFormat
  Span  : SpanFormat
  Class : ClassFormat
  Style : StyleFormat

  Bold      : BoldFormat
  Italic    : ItalicFormat
  Link      : LinkFormat
  Strike    : StrikeFormat
  Underline : UnderlineFormat

  BackColor : BackColorFormat
  FontName  : FontNameFormat
  FontSize  : FontSizeFormat
  ForeColor : ForeColorFormat
