module.exports = (grunt) ->
  require('load-grunt-tasks')(grunt)

  grunt.initConfig({
    pkg: grunt.file.readJSON('package.json')
  })

  require('./grunt/build')(grunt)
  require('./grunt/tests')(grunt)
  require('./grunt/concurrent')(grunt)
  require('./grunt/watch')(grunt)

  grunt.registerTask('default', ['clean', 'copy', 'concurrent:template', 'concurrent:browserify', 'uglify', 'concat'])

  grunt.registerTask('test', ['karma:test'])
  grunt.registerTask('test:unit', ['karma:unit'])
  grunt.registerTask('test:functional', ['karma:functional'])
  grunt.registerTask('test:karma', ['karma:karma'])
  grunt.registerTask('test:exhaust', ['karma:exhaust'])
  grunt.registerTask('test:local', ['karma:local'])
  grunt.registerTask('test:remote', ['karma:remote-mac', 'karma:remote-windows', 'karma:remote-linux', 'karma:remote-mobile', 'karma:remote-legacy'])

  grunt.registerTask('test:wd', ['shell:wd-chrome-test'])
  grunt.registerTask('test:fuzz', ['shell:wd-chrome-fuzzer'])
  grunt.registerTask('test:replay', ['shell:wd-chrome-replay'])
  grunt.registerTask('test:wd firefox', ['shell:wd-firefox-test'])
  grunt.registerTask('test:fuzz firefox', ['shell:wd-firefox-fuzzer'])
  grunt.registerTask('test:replay firefox', ['shell:wd-firefox-replay'])

  grunt.registerTask('test:coverage', ['coffee:coverage', 'shell:instrument', 'browserify:exposed', 'karma:coverage', 'clean:coverage'])
  grunt.registerTask('test:coverage:unit', ['coffee:coverage', 'shell:instrument', 'browserify:exposed', 'karma:coverage-unit', 'clean:coverage'])
