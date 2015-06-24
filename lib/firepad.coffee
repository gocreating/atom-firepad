{CompositeDisposable} = require 'atom'
Crypto = require 'crypto'
Firebase = require 'firebase'
Firepad = require './firepad-lib'
FirepadShare = require './firepad-share'
ShareSetupView = require './sharesetup-view'

module.exports =
  config:
    firebaseUrl:
      type: 'string'
      default: 'https://atom-firepad.firebaseio.com'

  shareStack: []

  activate: (state) ->
    @shareSetupView = new ShareSetupView
    @subscriptions = new CompositeDisposable

    @subscriptions.add atom.commands.add 'atom-text-editor', 'firepad:share': => @share()
    @subscriptions.add atom.commands.add 'atom-text-editor', 'firepad:unshare': => @unshare()

    @subscriptions.add atom.workspace.observeActivePaneItem => @updateShareView()

    @subscriptions.add @shareSetupView.onDidConfirm (shareIdentifier) => @createShare(shareIdentifier)

  consumeStatusBar: (statusBar) ->
    ShareStatusBarView = require './views/share-status-bar'
    @shareStatusBarView ?= new ShareStatusBarView()
    @shareStatusBarTile = statusBar.addRightTile(item: @shareStatusBarView, priority: 100)

  deactivate: ->
    @subscriptions.dispose()

    @statusBarTile?.destroy()
    @statusBarTile = null

  createShare: (shareIdentifier) ->
    # hash = Crypto.createHash('sha256').update(@shareIdentifier).digest('base64')
    # @firebase = new Firebase(atom.config.get('firepad.firebaseUrl')).child(hash)
    #
    # editor = atom.workspace.getActiveTextEditor()
    # @firebase.once 'value', (snapshot) =>
    #   options = {sv_: Firebase.ServerValue.TIMESTAMP}
    #   if not snapshot.val() and editor.getText() isnt ''
    #     options.overwrite = true
    #   else
    #     editor.setText ''
    #   @firepad = Firepad.fromAtom @firebase, editor, options
    #   @shareview.show(@shareIdentifier)

    if shareIdentifier
      editor = atom.workspace.getActiveTextEditor()

      editorIsShared = false
      for share in @shareStack
        if share.getEditor() is editor
          editorIsShared = true

      if not editorIsShared
        share = new FirepadShare(editor, shareIdentifier)
        @subscriptions.add share.onDidDestroy => @destroyShare(share)

        @shareStack.push share
        @updateShareView()

      else
        atom.notifications.addError('Pane is shared')

    else
      atom.notifications.addError('No session key set')

  destroyShare: (share) ->
    shareStackIndex = @shareStack.indexOf share
    if shareStackIndex isnt -1
      @shareStack.splice shareStackIndex, 1
      @updateShareView()

    else
      console.error share, 'not found'

  updateShareView: ->
    if @shareStatusBarView
      editor = atom.workspace.getActiveTextEditor()

      editorIsShared = false
      for share in @shareStack
        if share.getEditor() is editor
          editorIsShared = true
          @shareStatusBarView.show(share.getShareIdentifier())

      if not editorIsShared
        @shareStatusBarView.hide()

  share: ->
    @shareSetupView.show()

  unshare: ->
    # @shareview.detach()
    # @firepad.dispose()
    editor = atom.workspace.getActiveTextEditor()

    editorIsShared = false
    for share in @shareStack
      if share.getEditor() is editor
        editorIsShared = true
        share.remove()

    if not editorIsShared
      atom.notifications.addError('Pane is not shared')
