imports = [
  'bootstrap'
  'h.services'
]

# Indexer service
class Indexer
  # We do not index hints which are shorter than this constant.
  hint_minimum_length = 3

  indexes =
    text:
      counts: {}
      mapping: {}
    quote:
      counts: {}
      mapping: {}
    user:
      counts: {}
      mapping: {}
    tag:
      counts: {}
      mapping: {}
    any:
      counts: {}
      mapping: {}

  hints =
    text: []
    quote: []
    user: []
    tag: []
    any: []


  # This can be a binary search based insert in the future
  addHint: (field, hint) ->
    added = false

    for h, index in @hints[field]
      if hint < h
        @hints[field] = @hints[field].splice index, 0, hint
        added = true
        break

    # New last item
    if not added then @hints[field].push hint
    return

  removeHint: (field, hint) ->
    @hints[field] = @hints[field].filter (e) -> e isnt hint
    return

  getHints: (field, beginning) ->
    hints = []
    reached = false
    for hint in @hints[field]
      if hint.indexOf beginning is 0
        reached = true
        hints.push hint
      else
        if reached then break
    hints

  this.$inject = [
    '$filter', '$scope', 'annotator'
  ]
  constructor: ($filter, $scope, annotator) ->
    username = $filter persona
    @fields =
      text: (e) -> [e.text]
      quote: (e) ->
          quotes = []
          for target in e.target
            quotes.push target.quote if target.quote?
          quotes
      user: (e) =>
          [username e.user]
      tag: (e) ->
          e.tags
      any: (e) =>
        any = []
        any.push e.text if e.text?
          for target in e.target
            any.push target.quote if target.quote?
        any.push username e.user if e.user?
        any.push tag for tag in e.tags
        any


    @createIndex = (annotations) =>
      for annotation in annotations
        for name, field of @fields
          @indexes[name].mappings[annotation.id] = []
          data = field annotation
          for d in data
            pieces = d.split /\s/g
            for piece in pieces
              continue if piece.length < @hint_minimum_length

              @indexes[name].mappings[annotation.id].push piece
              if piece of @indexes[name].counts
                @indexes[name].counts[piece]++
              else
                @indexes.data.push piece
                @indexes[name].counts[piece] = 1
                @addHint name, piece

    @deleteIndex = (annotation) =>
      for name, field of @fields
        data = field annotation
        for d in data
          pieces = d.split /\s/g

          for piece in pieces
            continue if piece.length < @hint_minimum_length
            @indexes[name].counts[piece]--

            if not piece of @indexes[name].counts
              @indexes.data.remove piece
              delete @indexes[name].counts[piece]
              @removeHint name, piece
        delete @indexes[name].mappings[annotation.id]

    @updateIndex = (annotation) =>
      @deleteIndex annotation
      @createIndex [annotation]

    annotator.subscribe 'annotationsLoaded', @createIndex
    annotator.subscribe 'annotationUpdated', @updateIndex
    annotator.subscribe 'annotationDeleted', @deleteIndex


    $scope.$on '$destroy', ->
      annotator.unsubscribe 'annotationsLoaded', @createIndex
      annotator.unsubscribe 'annotationUpdated', @updateIndex
      annotator.unsubscribe 'annotationDeleted', @deleteIndex

angular.module('h.services.indexer', imports)
.service('indexer', Indexer)