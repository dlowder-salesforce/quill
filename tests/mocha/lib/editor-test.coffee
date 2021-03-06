Tandem = require('tandem-core')
QuillHtmlTest = require('./html-test')

class QuillEditorTest extends QuillHtmlTest
  @DEFAULTS:
    ignoreExpect  : false

  constructor: (options = {}) ->
    @settings = _.defaults(options, QuillEditorTest.DEFAULTS)
    super(@settings)

  run: (name, options, args...) ->
    it(name, (done) =>
      this.runWithoutIt(options, args..., done)
    )

  runWithoutIt: (options, args..., done) ->
    throw new Error("Invalid options passed into run") unless _.isObject(options)
    @options = _.defaults(options, @settings)
    testEditor = expectedEditor = null
    htmlOptions = _.clone(@options)
    htmlOptions.initial = '' if Tandem.Delta.isDelta(htmlOptions.initial)
    htmlOptions.expected = '' if Tandem.Delta.isDelta(htmlOptions.expected)
    htmlOptions.fn = (testContainer, expectedContainer, args...) =>
      testEditor = new Quill(testContainer) #, { logLevel: 'debug' })
      expectedEditor = new Quill(expectedContainer) #, { logLevel: 'debug' })
      testEditor.setContents(@options.initial) if Tandem.Delta.isDelta(@options.initial)
      expectedEditor.setContents(@options.expected) if Tandem.Delta.isDelta(@options.expected)
      @options.fn.call(null, testEditor, expectedEditor, args...)
    checkDeltas = (testEditor, expectedEditor) =>
      unless @options.ignoreExpect
        testDelta = testEditor.getContents()
        expectedDelta = expectedEditor.getContents()
        isEqual = testDelta.isEqual(expectedDelta)
        console.error("Unequal deltas", testDelta, expectedDelta) unless isEqual
        expect(isEqual).to.be(true)
        # TODO fix this
        consistent = expect.consistent(testEditor.editor.doc)
        console.error("Editors not consistent", testEditor, expectedEditor) unless consistent
        expect(consistent).to.be(true)
    htmlOptions.checker = (testContainer, expectedContainer, args..., callback) =>
      @options.checker.call(this, testEditor, expectedEditor, args..., ->
        checkDeltas(testEditor, expectedEditor)
        done()
      )
      if @options.checker.length <= args.length + 2
        checkDeltas(testEditor, expectedEditor)
        done()
    super(htmlOptions, args..., done)

module.exports = QuillEditorTest
