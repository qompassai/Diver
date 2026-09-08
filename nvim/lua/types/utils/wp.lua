-- /qompassai/Diver/lua/types/config/wp.lua
-- Qompass AI Diver WirePlumber Types Config
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
---@meta
---@alias                    WPAccess
---| 'unrestricted'
---| 'default'
---| 'flatpak'
---| 'restricted'
---| 'flatpak-manager'
---| nil
---@alias                    WPMatchRuleCallback           fun(action: string, value: WPJsonObject)
---@alias                    WPPermissions
---| 'all'
---| 'rx'
---@alias                    WPPropValue                   string|number|boolean|nil
---@class                    Client                        :WPClient
---@class                    WPAudioNamespace              :string
---@type                     WPAudioNamespace
PW_AUDIO_NAMESPACE = PW_AUDIO_NAMESPACE
---@class                    WPAudioStreamProps            :WPProperties
---@field ['media.class']?                                 string
---@class                    WPAsyncEventHook              :WPObject
---@field register?                                        fun(self: WPAsyncEventHook)
---@field remove?                                          fun(self: WPAsyncEventHook)
---@param opts?                                            { name: string, interests: WPEventInterest[], steps: table<string, { next: string, execute: fun(event: WPEvent, transition: WPAsyncTransition) }> }
---@return                   WPAsyncEventHook
function AsyncEventHook(opts) end

---@class                    WPAsyncTransition
---@field advance?                                         fun(self: WPAsyncTransition)
---@field return_error?                                    fun(self: WPAsyncTransition, msg: string)
---@class                    WPBluezMidiConfig
---@field servers?                                         string[]
---@field properties?                                      WPProperties|nil
---@field seat_monitoring?                                 boolean
---@field rules?                                           WPJsonObject
---@class                    WPCameraData
---@field factory?                                         string
---@field id?                                              integer
---@field obj_path?                                        string
---@field parent?                                          WPObject
---@field properties?                                      WPProperties
---@class                    WPClient                      :WPObject
---@field properties?                                      WPProperties
---@field update_permissions?                              fun(self: WPClient, perms: table<any, string>)
---@class                    WPConstraint
---@field key?                                             string
---@field operator?                                        string
---@field value?                                           any
---@param c?                                               { [1]: string, [2]: string, [3]: any, type?: string }
---@return                   WPConstraint
local function Constraint_ctor(c) end
---@type                                                   fun(c: { [1]: string, [2]: string, [3]: any, type?: string }): WPConstraint
Constraint = Constraint or Constraint_ctor
---@class                    WPCore
---@field get_vm_type?                                     fun(): string|nil
---@field get_properties?                                  fun(): WPProperties
---@field sync?                                            fun(callback: fun()): nil
---@field test_feature?                                    fun(feature: string): boolean
---@field timeout_add?                                     fun(timeout_ms: number, callback: fun(): boolean): WPGSource
---@field update_properties?                               fun(props: table<string, string>): nil
---@type                     WPCore
Core = Core
---@class                    WPDevice                      :WPObject
---@field iterate_params?                                  fun(self: WPDevice, id: string): fun(): any
---@class                    WPEvent
---@field get_data?                                        fun(self: WPEvent, key: string): any
---@field get_properties?                                  fun(self: WPEvent): table<string, any>
---@field get_source?                                      fun(self: WPEvent): WPObject
---@field get_subject?                                     fun(self: WPEvent): WPObject
---@field set_data?                                        fun(self: WPEvent, key: string, value: any)
---@field stop_processing?                                 fun(self: WPEvent)
---@class                    WPDspRuleProps
---@field ['filter-graph']?                                table
---@field ['filter-path']?                                 table
---@field ['hide-parent']?                                 boolean
---@class                    WPEventDispatcher
---@field push_event?                                      fun(event: WPEvent)
---@type                     WPEventDispatcher
EventDispatcher = EventDispatcher
---@class                    WPEventInterest
---@param spec?                                            WPConstraint[]
---@return                   WPEventInterest
local function EventInterest_ctor(spec) end
---@type                     fun(spec:WPConstraint[]):     WPEventInterest
EventInterest = EventInterest or EventInterest_ctor
---@class                    WPFeatureNs
---@field Proxy?                                           WPProxyFeatures
---@field SpaDevice?                                       WPSpaDeviceFeatures
---@field SessionItem?                                     WPSessionItemFeature
---@type                     WPFeatureNs
Feature = Feature
---@class                    WPFeatureFlags
---@field ALL?                                             integer
---@type                     WPFeatureFlags
Features = Features
---@class                    WPFilterNodes                 :table<integer, WPLocalModule>
---@type                     WPFilterNodes
filter_nodes = filter_nodes
---@class                    WPGSource
---@field destroy?                                         fun(self: WPGSource)
---@class                    WPGroupLoopbackInner          :table<string, WPLocalModule>
---@class                    WPGroupLoopbackModules        :table<'input'|'output', WPGroupLoopbackInner>
---@type                     WPGroupLoopbackModules
group_loopback_modules = group_loopback_modules
---@class                    WPHiddenNodes                 :table<integer, integer>
---@type                     WPHiddenNodes
hidden_nodes = hidden_nodes
---@class                    WPI18n
---@field gettext?                                         fun(msgid: string): string
---@type                     WPI18n
I18n = I18n
---@class                     WPInterest
---@class                     WPInterestSpec
---@field type?                                            string
---@param spec?                                            WPInterestSpec
---@return                   WPInterest
local function Interest_ctor(spec) end
---@type                     fun(spec:WPInterestSpec):     WPInterest
Interest = Interest or Interest_ctor
---@class                     WPItemMap                    :table<integer, WPSessionItem>
---@type                      WPItemMap
items = items
---@class                     WPJson
---@field Array?                                           fun(t: table): WPJsonObject
---@field Object?                                          fun(tbl: table): WPJsonObject
---@field Raw?                                             fun(obj: any): WPJsonObject
---@type                      WPJson
Json = Json
---@class                     WPJsonObject
---@field get_data?                                        fun(self: WPJsonObject): table
---@field is_array?                                        fun(self: WPJsonObject): boolean
---@field is_boolean?                                      fun(self: WPJsonObject): boolean
---@field is_string?                                       fun(self: WPJsonObject): boolean
---@field is_object?                                       fun(self: WPJsonObject): boolean
---@field parse?                                           fun(self: WPJsonObject, flags?: integer): any
---@field to_string?                                       fun(self: WPJsonObject): string
---@class                    WPDSPConfig
---@field rules?                                           WPJsonObject
---@class                    WPJsonUtils
---@field match_rules                                      fun(
---  self?:                                                WPJsonUtils,
---  rules:                                                WPJsonObject,
---  props:                                                WPProperties,
---  cb:                                                   WPMatchRuleCallback)
---@field                                                  match_rules_update_properties fun(
---  self?:                                                WPJsonUtils,
---  rules:                                                WPJsonObject,
---  props:                                                WPProperties): WPProperties
---@type                     WPJsonUtils
JsonUtils = JsonUtils

---@class                    WPLocalModule
---@field destroy?                                         fun(self: WPLocalModule)
---@param name?                                            string
---@param args?                                            table
---@param opts?                                            table
---@return                   WPLocalModule
local function LocalModule_ctor(name, args, opts) end
---@type                                                   fun(name: string, args: table, opts: table): WPLocalModule
LocalModule = LocalModule or LocalModule_ctor
---@class                    WPLog
---@field debug?                                           fun(self: WPLog, subject: any|nil, msg: string)
---@field error?                                           fun(...: any)
---@field info?                                            fun(self: WPLog, si: any, msg: string)
---@field notice?                                          fun(...: any)
---@field open_topic?                                      fun(name: string): WPLog
---@field trace?                                           fun(...: any)
---@field warning?                                         fun(self: WPLog, object: any|nil, message: string)
---@class                    WPMetadata                    :WPObject
---@field activate?                                        fun(self: WPMetadata, features: integer, cb: fun(self: WPMetadata, e: any)): nil
---@field changed?                                         fun(self: WPMetadata, subject: integer, key: string)
---@field find?                                            fun(self: WPMetadata, subject: integer, key: string): string|nil
---@field name?                                            string
---@field set?                                             fun(self: WPMetadata, subject: integer, key: string, type: string, value: string)
---@type                     WPMetadata
Metadata = Metadata
---@class                    WPMetadataEvent               :WPEvent
---@field get_subject?                                     fun(self: WPMetadataEvent): WPMetadata
---@class                    WPNode                        :WPObject
---@field activate?                                        fun(self: WPNode, features: integer, cb?: fun(self: WPNode, err: any)): nil
---@field get_active_features?                             fun(self: WPNode): integer
---@field iterate_params?                                  fun(self: WPNode, id: string): fun(): any
---@field properties?                                      WPProperties
---@field request_destroy?                                 fun(self: WPNode)
---@field send_command?                                    fun(self: WPNode, command: string)
---@field set_param?                                       fun(self: WPNode, id: string, pod: any)
---@field set_params?                                      fun(self: WPNode, id: string, pod: any)
---@field state?                                           string
---@param factory?                                         string
---@param props?                                           WPProperties
---@return                   WPNode
function Node(factory, props) end

---@type                     WPNode[]|nil
servers = servers
---@param factory?                                         string
---@param props?                                           WPProperties
---@return                   WPNode
function LocalNode(factory, props) end

---@class                    WPNodeDirectionMap            : table<integer, 'input'|'output'>
---@type                     WPNodeDirectionMap
node_directions = node_directions
---@class                    WPNodeEvent                   :WPEvent
---@field get_subject?                                     fun(self: WPNodeEvent): WPNode
---@see                      WpObject
---@class                    WPNodeFixed                   :WPNode
---@field id                                               integer
---@class                     WPObject
---@field call?                                            fun(self: WPObject, method: string, ...: any): any
---@field connect?                                         fun(self: WPObject, signal: string, callback: fun(...: any))
---@field get_associated_proxy?                            fun(self: WPObject, role: string): WPObject|WPNode|nil
---@field get_properties?                                  fun(self: WPObject): WPProperties
---@field get_property?                                    fun(self: WPObject, key: string): any
---@field id                                               integer
---@field lookup_port?                                     fun(self: WPObject, constraints: table): WPObject|nil
---@field properties?                                      WPProperties
---@field set_param?                                       fun(self: WPObject, id: string, param: any)
---@field set_params?                                      fun(self: WPObject, id: string, param: any)
---@field update_permissions?                              fun(self: WPClient, perms: table<any, string>)
---@class                     WPObjectManager
---@field activate?                                        fun(self: WPObjectManager)
---@field connect?                                         fun(
---  self:                                                 WPObjectManager,
---  signal:                                               string,
---  cb:                                                   fun(om: WPObjectManager, obj: WPObject),
---  data?:                                                any)
---@field get_managed_object?                              fun(self: WPObjectManager, id: number|nil): WPObject|nil
---@field iterate?                                         fun(self: WPObjectManager, filter?: table): fun(): WPObject
---@field lookup?                                          fun(self: WPObjectManager, id: any): WPObject|WPMetadata|nil
---@param spec?                                            WPInterest[]
---@return                    WPObjectManager
local function ObjectManager_ctor(spec) end
---@type                      fun(spec:                    WPInterest[]): WPObjectManager
ObjectManager = ObjectManager or ObjectManager_ctor
---@class                     WPProcInfo
---@field get_arg?                                         fun(self: WPProcInfo, index: integer): string|nil
---@field get_n_args?                                      fun(self: WPProcInfo): integer
---@field get_parent_pid?                                  fun(self: WPProcInfo): integer
---@class                     WPProcUtils
---@field get_proc_info?                                   fun(pid: number): WPProcInfo
---@type                      WPProcUtils
ProcUtils = ProcUtils
---@class                     WPProperties                 :table<string, WPPropValue>
---@field get_boolean?                                     fun(self: WPProperties, key: string): boolean|nil | nil
---@field get_int?                                         fun(self: WPProperties, key: string): integer|nil | nil
---@field get_string?                                      fun(self: WPProperties, key: string): string|nil | nil
---@class                    WPProxyFeatures
---@field BOUND?                                           integer
---@class                    WPSessionItem                 :WPObject
---@field activate?                                        fun(self: WPSessionItem, features: integer, cb: fun(self: WPSessionItem, e: any))
---@field configure?                                       fun(self: WPSessionItem, props: table): boolean
---@field connect?                                         fun(self: WPSessionItem, signal: string, cb: fun(item: WPSessionItem, old_state: string, new_state: string))
---@field get_associated_proxy?                            fun(self: WPSessionItem, kind: string): WPNode|WPObject|nil
---@field get_ports_format?                                fun(self: WPSessionItem): any, any
---@field id?                                              integer
---@field properties?                                      WPProperties
---@field register?                                        fun(self: WPSessionItem)
---@field remove?                                          fun(self: WPSessionItem)
---@field set_ports_format?                                fun(self: WPSessionItem, f: any, m: any, cb: fun(item: WPSessionItem, e: any))
---@param type_name                                        string
---@return                   WPSessionItem
function SessionItem(type_name) end

---@class                    WPSessionItemEvent            :WPEvent
---@field get_subject?                                     fun(self: WPSessionItemEvent): WPSessionItem
---@class                    WPSessionItemFeature
---@field ACTIVE?                                          integer
---@class                    WPSessionItemFixed            :WPSessionItem
---@field id                                               integer
---@class                    WPSessionItemLink             :WPObject
---@field get_active_features?                             fun(self: WPSessionItemLink): integer
---@field properties?                                      WPProperties
---@field remove?                                          fun(self: WPSessionItemLink)
---@class                    WPSessionItemManager          :WPObjectManager
---@field iterate?                                         fun(self: WPSessionItemManager, filter?: table): fun(): WPSessionItem|WPSessionItemLink
---@field lookup?                                          fun(self: WPSessionItemManager, args: table): WPObject|nil
---@class                    WPSettings
---@field get?                                             fun(key: string): WPJsonObject|nil
---@field get_boolean?                                     fun(key: string): boolean
---@field get_float?                                       fun(key: string): number
---@field subscribe?                                       fun(key: string, cb: fun()): nil
---@type                     WPSettings
---@class                    WPSimpleEventHook             :        WPObject
---@field register?                                        fun(self: WPSimpleEventHook)
---@field remove?                                          fun(self: WPSimpleEventHook)

---@param opts?                                            { name: string, interests: WPEventInterest[], execute: fun(event: WPEvent) }
---@return                   WPSimpleEventHook
function SimpleEventHook(opts) end

---@type                                                   fun(opts: { name: string, interests: WPEventInterest[], execute: fun(event: WPEvent) }): WPSimpleEventHook
SimpleEventHook = SimpleEventHook
---@class                    SimpleEventHookClass
---@field new                                              fun(opts: { name: string, interests: WPEventInterest[], execute: fun(event: WPEvent) }): WPSimpleEventHook
---@class                    WPSpaDevice                   :WPObject
---@field activate?                                        fun(self: WPSpaDevice, features: integer): nil
---@field connect?                                         fun(self: WPSpaDevice, signal: string, cb: fun(...: any))
---@field deactivate?                                      fun(self: WPSpaDevice, features: integer): nil
---@field get_managed_object?                              fun(
---   self:                                                WPSpaDevice,
---   id:                                                  number|nil): WPObject|WPLocalModule|nil
---@field set_managed_pending?                             fun(self: WPSpaDevice, id: number): nil
---@field store_managed_object?                            fun(
---   self:                                                WPSpaDevice,
---   id:                                                  number,
---   obj:                                                 WPObject|WPLocalModule|nil): nil
---@param factory?                                         string
---@param props?                                           WPProperties
---@return                                                 WPSpaDevice|nil
function SpaDevice(factory, props) end

---@type                     WPSpaDevice|nil
monitor = monitor
---@type                     WPSpaDevice|nil
bluetooth_monitor = bluetooth_monitor
---@class                    WPSpaDeviceFeatures
---@field ENABLED?                                         integer
---@class WPState
---@field save_after_timeout?                              fun(self: WPState, tbl: table)
---@class WPUtils
---@field cam_data?                                        WPCameraData[] mutils
---@field cam_source?                                      WPGSource|nil mutils
---@field canLink?                                         fun(self: WPUtils, si_props: WPProperties, target: WPSessionItem): boolean
---@field checkFilter                                      fun(self: WPUtils, si: WPSessionItem, om: WPSessionItemManager, handle_nonstreams: boolean): boolean
---@field checkFollowDefault?                              fun(self: WPUtils, si: WPSessionItem, target: WPSessionItem|nil)
---@field checkPassthroughCompatibility?                   fun(self: WPUtils, si: WPSessionItem, target: WPSessionItem): boolean, boolean
---@field clear_flags?                                     fun(self: WPUtils, id: integer): nil
---@field clearPriorityMediaRoleLink?                      fun(self: WPUtils, link: WPObject): nil
---@field contains_audio_group?                            fun(group: string): boolean autils
---@field create_cam_nodes?                                fun(self: WPUtils)
---@field isLinked?                                        fun(target: WPSessionItem): boolean, boolean
---@field findDefaultLinkable?                             fun(si: WPSessionItem): WPSessionItem|nil
---@field find_duplicate?                                  fun(parent: WPObject, id: number, property: string, value: WPPropValue): boolean
---@field get_application_name?                            fun(): string   cutils
---@field get_audio_group?                                 fun(node: any): string|nil
---@field get_default_metadata_object?                     fun(): WPMetadata
---@field get_flags?                                       fun(self: WPUtils, id: integer): table
---@field get_object_manager?                              fun(kind: string): WPObjectManager cutils
---@field getTargetDirection?                              fun(properties: WPProperties): 'input'|'output'
---@field haveAvailableRoutes?                             fun(self: WPUtils, props: WPProperties): boolean
---@field is_filter_smart?                                 fun(direction: string, link_group: string|nil): boolean
---@field is_filter_disabled?                              fun(direction: string, link_group: string|nil): boolean
---@field is_role_policy_target?                           fun(si_props: WPProperties, target_props: WPProperties): boolean
---@field lookupLink?                                      fun(si_id: integer, peer_id: integer): WPSessionItemLink|nil
---@field mediaClassToDirection?                           fun(media_class: string): 'input'|'output'|nil
---@field parseBool?                                       fun(var: any): boolean  cutils
---@field parseParam?                                      fun(param: any, id: string): any
---@field ports_state_signal?                              boolean|nil
---@field register_cam_node?                               fun(self: WPUtils, parent: WPObject, id: integer, factory: string, properties: WPProperties)
---@field sendClientError?                                 fun(self: WPUtils, event: WPEvent, node: WPNode|nil, code: integer, msg: string)
---@field set_audio_group?                                 fun(node: any, group: string|nil)
---@field unwrap_select_target_event?                      fun(
---  self:                                                 WPUtils,
---  event:                                                WPEvent): WPObject, WPSessionItemManager, WPSessionItem, WPProperties, table, WPSessionItem|nil
---@field updatePriorityMediaRoleLink?                     fun(link: WPSessionItem)
---@type                                                   WPUtils
cutils = cutils
---@type                                                   WPUtils
futils = futils
---@type                                                   WPUtils
lutils = lutils
---@class                    WPV4L2Config
---@field properties?                                      WPProperties