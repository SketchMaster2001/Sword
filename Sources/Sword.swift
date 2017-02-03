//
//  Sword.swift
//  Sword
//
//  Created by Alejandro Alonso
//  Copyright © 2017 Alejandro Alonso. All rights reserved.
//

import Foundation

/// Main Class for Sword
public class Sword: Eventer {

  // MARK: Properties

  /// Endpoints structure
  let endpoints = Endpoints()

  /// The gateway url to connect to
  var gatewayUrl: String?

  /// Array of guilds the bot is currently connected to
  public internal(set) var guilds: [String: Guild] = [:]

  /// Optional options to apply to bot
  var options: SwordOptions

  /// Timestamp of ready event
  public internal(set) var readyTimestamp: Date?

  /// Requester class
  let requester: Request

  /// Amount of shards to initialize
  public internal(set) var shardCount = 1

  /// Array of Shard class
  var shards: [Shard] = []

  /// The bot token
  let token: String

  /// Array of unavailable guilds the bot is currently connected to
  public internal(set)var unavailableGuilds: [String: UnavailableGuild] = [:]

  /// Int in seconds of how long the bot has been online
  public var uptime: Int? {
    if self.readyTimestamp != nil {
      return Int((Date() - self.readyTimestamp!.timeIntervalSince1970).timeIntervalSince1970)
    }else {
      return nil
    }
  }

  /// The user account for the bot
  public internal(set) var user: User?

  /// Object of voice connections the bot is currently connected to. Mapped by guildId
  public var voiceConnections: [String: VoiceConnection] {
    return self.voiceManager.connections
  }

  /// Voice handler
  let voiceManager = VoiceManager()

  // MARK: Initializer

  /**
   Initializes the Sword class

   - parameter token: The bot token
   - parameter options: Options to give bot (sharding, offline members, etc)
   */
  public init(token: String, with options: SwordOptions = SwordOptions()) {
    self.options = options
    self.requester = Request(token)
    self.token = token
    super.init()
  }

  // MARK: Functions

  /// Gets the gateway URL to connect to
  func getGateway(completion: @escaping (RequestError?, [String: Any]?) -> ()) {
    self.requester.request(self.endpoints.gateway, rateLimited: false) { error, data in
      if error != nil {
        completion(error, nil)
        return
      }

      guard let data = data as? [String: Any] else {
        completion(.unknown, nil)
        return
      }

      completion(nil, data)
    }
  }

  /// Starts the bot
  public func connect() {
    self.getGateway() { error, data in
      if error != nil {
        guard error == .unauthorized else {
          sleep(3)
          self.connect()
          return
        }

        print("[Sword] Bot token invalid.")
      }else {
        self.gatewayUrl = "\(data!["url"]!)/?encoding=json&v=6"

        if self.options.isSharded {
          self.shardCount = data!["shards"] as! Int
        }else {
          self.shardCount = 1
        }

        for id in 0..<self.shardCount {
          let shard = Shard(self, id, self.shardCount)
          self.shards.append(shard)
          shard.startWS(self.gatewayUrl!)
        }

      }
    }
  }

  /**
   Adds a user to guild

   - parameter userId: User to add
   - parameter guildId: The guild to add user in
   - parameter options: Initial options to equip user with in guild
   */
  public func add(user userId: String, to guildId: String, with options: [String: Any] = [:], _ completion: @escaping (Member?) -> () = {_ in}) {
    self.requester.request(endpoints.addGuildMember(guildId, userId), body: options.createBody(), method: "PUT") { error, data in
      if error != nil {
        completion(nil)
      }else {
        completion(Member(self, data as! [String: Any]))
      }
    }
  }

  /**
   Creates an invite for channel

   - parameter channelId: Channel to create invite for
   - parameter options: Options to give invite
   */
  public func createInvite(for channelId: String, with options: [String: Any] = [:], _ completion: @escaping (Any?) -> () = {_ in}) {
    self.requester.request(endpoints.createChannelInvite(channelId), body: options.createBody(), method: "POST") { error, data in
      if error != nil {
        completion(nil)
      }else {
        completion(data)
      }
    }
  }

  /**
   Deletes a channel

   - parameter channelId: Channel to delete
   */
  public func delete(channel channelId: String, _ completion: @escaping (Any?) -> () = {_ in}) {
    self.requester.request(endpoints.deleteChannel(channelId), method: "DELETE") { error, data in
      if error != nil {
        completion(nil)
      }else {
        let channelData = data as! [String: Any]
        if channelData["recipient"] == nil {
          completion(Channel(self, channelData))
        }else {
          completion(DMChannel(self, channelData))
        }
      }
    }
  }

  /**
   Deletes a guild

   - parameter guildId: Guild to delete
   */
  public func delete(guild guildId: String, _ completion: @escaping (Guild?) -> () = {_ in}) {
    self.requester.request(endpoints.deleteGuild(guildId), method: "DELETE") { error, data in
      if error != nil {
        completion(nil)
      }else {
        let guild = Guild(self, data as! [String: Any])
        self.guilds.removeValue(forKey: guild.id)
        completion(guild)
      }
    }
  }

  /**
   Deletes an invite

   - parameter inviteId: Invite to delete
   */
  public func delete(invite inviteId: String, _ completion: @escaping (Any?) -> () = {_ in}) {
    self.requester.request(endpoints.deleteInvite(inviteId), method: "DELETE") { error, data in
      if error != nil {
        completion(nil)
      }else {
        completion(data as! [String: Any])
      }
    }
  }

  /**
   Deletes a webhook

   - parameter webhookId: Webhook to delete
   */
  public func delete(webhook webhookId: String, _ completion: @escaping () -> () = {_ in}) {
    self.requester.request(endpoints.deleteWebhook(webhookId), method: "DELETE") { error, data in
      if error == nil { completion() }
    }
  }

  /**
   Deletes an overwrite permission for a channel

   - parameter channelId: Channel to delete permissions from
   - parameter overwriteId: Overwrite ID to use for permissons
   */
  public func deletePermission(for channelId: String, with overwriteId: String, _ completion: @escaping () -> () = {_ in}) {
    self.requester.request(endpoints.deleteChannelPermission(channelId, overwriteId), method: "DELETE") { error, data in
      if error == nil { completion() }
    }
  }

  /**
   Edits a channel

   - parameter channelId: Channel to edit
   - parameter options: Optons to give channel
   */
  public func edit(channel channelId: String, with options: [String: Any] = [:], _ completion: @escaping (Channel?) -> () = {_ in}) {
    self.requester.request(endpoints.modifyChannel(channelId), body: options.createBody(), method: "PATCH") { error, data in
      if error != nil {
        completion(nil)
      }else {
        completion(Channel(self, data as! [String: Any]))
      }
    }
  }

  /**
   Edits a channel's overwrite permission

   - parameter permissions: ["allow": perm#, "deny": perm#, "type": "role" || "member"]
   - parameter channelId: Channel to edit permissions for
   - parameter overwriteId: Overwrite ID to use for permissions
   */
  public func edit(permissions: [String: Any], for channelId: String, with overwriteId: String, _ completion: @escaping () -> () = {_ in}) {
    self.requester.request(endpoints.editChannelPermissions(channelId, overwriteId), body: permissions.createBody(), method: "PUT") { error, data in
      if error == nil { completion() }
    }
  }

  /**
   Edits bot status

   - parameter presence: Presence structure to set status to
   */
  public func editStatus(to presence: Presence) {
    guard self.shards.count > 0 else { return }
    var data: [String: Any] = ["afk": presence.status == .idle, "game": NSNull(), "since": presence.status == .idle ? Date().milliseconds : 0, "status": presence.status.rawValue]

    if presence.game != nil {
      data["game"] = ["name": presence.game]
    }

    let payload = Payload(op: .statusUpdate, data: data).encode()

    for shard in self.shards {
      shard.send(payload, presence: true)
    }
  }

  /**
   Executes a webhook

   - parameter webhookId: Webhook to execute
   - parameter webhookToken: Token for auth to execute
   - parameter content: String or dictionary containing message content
   */
  public func execute(webhook webhookId: String, token webhookToken: String, with content: Any, _ completion: @escaping () -> () = {_ in}) {
    guard let message = content as? [String: Any] else {
      let data = ["content": content].createBody()
      self.requester.request(endpoints.executeWebhook(webhookId, webhookToken), body: data, method: "POST") { error, data in
        if error == nil { completion() }
      }
      return
    }
    var file: [String: Any] = [:]
    var parameters: [String: String] = [:]

    if message["file"] != nil {
      file["file"] = message["file"] as! String
    }
    if message["content"] != nil {
      parameters["content"] = (message["content"] as! String)
    }
    if message["tts"] != nil {
      parameters["tts"] = (message["tts"] as! String)
    }
    if message["embed"] != nil {
      parameters["payload_json"] = (message["embed"] as! [String: Any]).encode()
    }
    if message["username"] != nil {
      parameters["username"] = (message["user"] as! String)
    }
    if message["avatar_url"] != nil {
      parameters["avatar_url"] = (message["avatar_url"] as! String)
    }

    file["parameters"] = parameters

    self.requester.request(endpoints.executeWebhook(webhookId, webhookToken), file: file, method: "POST") { error, data in
      if error == nil { completion() }
    }
  }

  /**
   Executs a slack style webhook

   - parameter webhookId: Webhook to execute
   - parameter webhookToken: Token for auth to execute
   */
  public func executeSlack(webhook webhookId: String, token webhookToken: String, with content: [String: Any], _ completion: @escaping () -> () = {_ in}) {
    self.requester.request(endpoints.executeSlackWebhook(webhookId, webhookToken), body: content.createBody(), method: "POST") { error, data in
      if error == nil { completion() }
    }
  }

  /**
   Gets a message from channel

   - parameter messageId: Message to get
   - parameter channelId: Channel to get message from
   */
  public func get(message messageId: String, from channelId: String, _ completion: @escaping (Message?) -> () = {_ in}) {
    self.requester.request(endpoints.getChannelMessage(channelId, messageId)) { error, data in
      if error != nil {
        completion(nil)
      }else {
        completion(Message(self, data as! [String: Any]))
      }
    }
  }

  /**
   Gets an array of messages from channel

   - parameter limit: Amount of messages to get
   - parameter channelId: Channel to get messages from
   */
  public func get(_ limit: Int, messagesFrom channelId: String, _ completion: @escaping ([Message]?) -> () = {_ in}) {
    if limit > 100 || limit < 1 { completion(nil); return }
    self.requester.request(endpoints.getChannelMessages(channelId), body: ["limit": limit].createBody()) { error, data in
      if error != nil {
        completion(nil)
      }else {
        var returnMessages: [Message] = []
        let messages = data as! [[String: Any]]
        for message in messages {
          returnMessages.append(Message(self, message))
        }
        completion(returnMessages)
      }
    }
  }

  /**
   Gets an invite

   - parameter inviteId: Invite to get
   */
  public func get(invite inviteId: String, _ completion: @escaping (Any?) -> () = {_ in}) {
    self.requester.request(endpoints.getInvite(inviteId)) { error, data in
      if error != nil {
        completion(nil)
      }else {
        completion(data as! [String: Any])
      }
    }
  }

  /**
   Gets a user from guild

   - parameter userId: User to get
   - parameter guildId: Guild to get user from
   */
  public func get(user userId: String, from guildId: String, _ completion: @escaping (Member?) -> () = {_ in}) {
    self.requester.request(endpoints.getGuildMember(guildId, userId)) { error, data in
      if error != nil {
        completion(nil)
      }else {
        let member = Member(self, data as! [String: Any])
        completion(member)
      }
    }
  }

  /**
   Gets a webhook

   - parameter webhookId: Webhook to get
   */
  public func get(webhook webhookId: String, _ completion: @escaping ([String: Any]?) -> ()) {
    self.requester.request(endpoints.getWebhook(webhookId)) { error, data in
      if error != nil {
        completion(nil)
      }else {
        completion(data as? [String: Any])
      }
    }
  }

  /**
   Gets a channel's invites

   - parameter channelId: Channel to get invites from
   */
  public func getInvites(for channelId: String, _ completion: @escaping (Any?) -> () = {_ in}) {
    self.requester.request(endpoints.getChannelInvites(channelId)) { error, data in
      if error != nil {
        completion(nil)
      }else {
        completion(data)
      }
    }
  }

  /**
   Function to get guild for channelId

   - parameter channelId: Channel to get guild from
  */
  public func getGuild(for channelId: String) -> Guild? {
    var guilds = self.guilds.filter {
      $0.1.channels[channelId] != nil
    }

    if guilds.isEmpty { return nil }
    return guilds[0].1
  }

  /**
   Restfully gets a channel

   - parameter channelId: Channel to get restfully
   */
  public func getREST(channel channelId: String, _ completion: @escaping (Any?) -> ()) {
    self.requester.request(endpoints.getChannel(channelId)) { error, data in
      if error != nil {
        completion(nil)
      }else {
        let channelData = data as! [String: Any]
        if channelData["recipient"] == nil {
          completion(Channel(self, channelData))
        }else {
          completion(DMChannel(self, channelData))
        }
      }
    }
  }

  /**
   Restfully gets a guild

   - parameter guildId: Guild to get restfully
   */
  public func getREST(guild guildId: String, _ completion: @escaping (Guild?) -> ()) {
    self.requester.request(endpoints.getGuild(guildId)) { error, data in
      if error != nil {
        completion(nil)
      }else {
        let guild = Guild(self, data as! [String: Any])
        self.guilds[guild.id] = guild
        completion(guild)
      }
    }
  }

  /**
   Restfully gets a user

   - parameter userId: User to get restfully
   */
  public func getREST(user userId: String, _ completion: @escaping (User?) -> ()) {
    self.requester.request(endpoints.getUser(userId)) { error, data in
      if error != nil {
        completion(nil)
      }else {
        completion(User(self, data as! [String: Any]))
      }
    }
  }

  /**
   Restfully gets channels from guild

   - parameter guildId: Guild to get channels from
   */
  public func getRESTChannels(from guildId: String, _ completion: @escaping ([Channel]?) -> ()) {
    self.requester.request(endpoints.getGuildChannels(guildId)) { error, data in
      if error != nil {
        completion(nil)
      }else {
        var returnChannels: [Channel] = []
        let channels = data as! [[String: Any]]
        for channel in channels {
          returnChannels.append(Channel(self, channel))
        }

        completion(returnChannels)
      }
    }
  }

  /// Restfully get guilds bot is in
  public func getRESTGuilds(_ completion: @escaping ([[String: Any]]?) -> ()) {
    self.requester.request(endpoints.getCurrentUserGuilds()) { error, data in
      if error != nil {
        completion(nil)
      }else {
        completion(data as? [[String: Any]])
      }
    }
  }

  /**
   Joins a voice channel

   - parameter channelId: Channel to connect to
  */
  public func join(voiceChannel channelId: String, _ completion: @escaping (VoiceConnection) -> () = {_ in}) {
    let guild = self.getGuild(for: channelId)

    guard guild != nil else { return }

    guard guild!.shard != nil else { return }

    let channel = guild!.channels[channelId]
    guard channel!.type != nil else { return }

    if channel!.type != 2 { return }

    let shard = self.shards.filter {
      $0.id == guild!.shard!
    }[0]

    self.voiceManager.handlers[guild!.id] = completion

    shard.join(voiceChannel: channelId, in: guild!.id)
  }

  /**
   Leaves a guild

   - parameter guildId: Guild to leave
   */
  public func leave(guild guildId: String, _ completion: @escaping () -> () = {_ in}) {
    self.requester.request(endpoints.leaveGuild(guildId), method: "DELETE") { error, data in
      if error == nil { completion() }
    }
  }

  /**
   Leaves a voice channel

   - parameter channelId: Channel to disconnect from
  */
  public func leave(voiceChannel channelId: String) {
    let guild = self.getGuild(for: channelId)

    guard guild != nil else { return }

    guard self.voiceManager.guilds[guild!.id] != nil else { return }

    guard guild!.shard != nil else { return }

    let channel = guild!.channels[channelId]

    guard channel!.type != nil else { return }

    if channel!.type != 2 { return }

    let shard = self.shards.filter {
      $0.id == guild!.shard!
    }[0]

    shard.leaveVoiceChannel(in: guild!.id)
  }

  /**
   Modifies a webhook

   - parameter webhookId: Webhook to modify
   - parameter options: ["name": "name of webhook", "avatar": "img data in base64"]
   */
  public func modify(webhook webhookId: String, with options: [String: String], _ completion: @escaping ([String: Any]?) -> () = {_ in}) {
    self.requester.request(endpoints.modifyWebhook(webhookId), body: options.createBody(), method: "PATCH") { error, data in
      if error != nil {
        completion(nil)
      }else {
        completion(data as? [String: Any])
      }
    }
  }

  /**
   Sends a message to channel

   - parameter content: Either string or dictionary containing info on message
   - parameter channelId: Channel to send message to
   */
  public func send(_ content: Any, to channelId: String, _ completion: @escaping (Message?) -> () = {_ in}) {
    guard let message = content as? [String: Any] else {
      let data = ["content": content].createBody()
      self.requester.request(endpoints.createMessage(channelId), body: data, method: "POST") { error, data in
        if error != nil {
          completion(nil)
        }else {
          completion(Message(self, data as! [String: Any]))
        }
      }
      return
    }
    var file: [String: Any] = [:]
    var parameters: [String: String] = [:]

    if message["file"] != nil {
      file["file"] = message["file"] as! String
    }
    if message["content"] != nil {
      parameters["content"] = (message["content"] as! String)
    }
    if message["tts"] != nil {
      parameters["tts"] = (message["tts"] as! String)
    }
    if message["embed"] != nil {
      parameters["payload_json"] = (message["embed"] as! [String: Any]).encode()
    }

    file["parameters"] = parameters

    self.requester.request(endpoints.createMessage(channelId), file: file, method: "POST") { error, data in
      if error != nil {
        completion(nil)
      }else {
        completion(Message(self, data as! [String: Any]))
      }
    }
  }

  /**
   Sets bot to typing in channel

   - parameter channelId: Channel to set typing to
   */
  public func setTyping(for channelId: String, _ completion: @escaping () -> () = {_ in}) {
    self.requester.request(endpoints.triggerTypingIndicator(channelId), method: "POST") { error, data in
      if error == nil { completion() }
    }
  }

  /**
   Sets bot's username

   - parameter name: Name to set bot's username to
   */
  public func setUsername(to name: String, _ completion: @escaping (User?) -> () = {_ in}) {
    self.requester.request(endpoints.modifyCurrentUser(), body: ["username": name].createBody(), method: "PATCH") { error, data in
      if error != nil {
        completion(nil)
      }else {
        let user = User(self, data as! [String: Any])
        self.user = user
        completion(user)
      }
    }
  }

}
