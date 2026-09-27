---@meta
-- luacheck: ignore 111 112 113 212
-- (bare globals by design in this generated ---@meta stub file)
-- Generated LuaCATS definitions for LOVE 11.5 (Mysterious Mysteries).
-- Source: love2d-community/love-api spec 11.5, generated 2026-09-27.
-- Machine-generated: do NOT hand-edit. See README.md for coverage gaps.
-- Bare-global ---@meta stubs (see lua/types/** convention); named stub params, <=120 cols.

---@class love
---@field audio love.audio
---@field data love.data
---@field event love.event
---@field filesystem love.filesystem
---@field font love.font
---@field graphics love.graphics
---@field image love.image
---@field joystick love.joystick
---@field keyboard love.keyboard
---@field math love.math
---@field mouse love.mouse
---@field physics love.physics
---@field sound love.sound
---@field system love.system
---@field thread love.thread
---@field timer love.timer
---@field touch love.touch
---@field video love.video
---@field window love.window
love = {}

--- Gets the current running version of LÖVE.
---@return number
--- The major version of LÖVE, i.e. 0 for version 0.9.1.
---@return number
--- The minor version of LÖVE, i.e. 9 for version 0.9.1.
---@return number
--- The revision version of LÖVE, i.e. 1 for version 0.9.1.
---@return string
--- The codename of the current version, i.e. 'Baby Inspector' for version 0.9.1.
function love.getVersion() end

--- Gets whether LÖVE displays warnings when using deprecated functionality. It is disabled by defau...
---@return boolean
--- Whether deprecation output is enabled.
function love.hasDeprecationOutput() end

--- Gets whether the given version is compatible with the current running version of LÖVE.
---@param major number
--- The major version to check (for example 11 for 11.3 or 0 for 0.10.2).
---@param minor number
--- The minor version to check (for example 3 for 11.3 or 10 for 0.10.2).
---@param revision number
--- The revision of version to check (for example 0 for 11.3 or 2 for 0.10.2).
---@overload fun(string)
---@return boolean
--- Whether the given version is compatible with the current running version of L...
function love.isVersionCompatible(major, minor, revision) end

--- Sets whether LÖVE displays warnings when using deprecated functionality. It is disabled by defau...
---@param enable boolean
--- Whether to enable or disable deprecation output.
function love.setDeprecationOutput(enable) end

--- If a file called conf.lua is present in your game folder (or .love file), it is run before the L?...
---@param t table
--- The love.conf function takes one argument: a table filled with all the defaul...
function love.conf(t) end

--- Callback function triggered when a directory is dragged and dropped onto the window.
---@param path string
--- The full platform-dependent path to the directory. It can be used as an argum...
function love.directorydropped(path) end

--- Called when the device display orientation changed, for example, user rotated their phone 180 deg...
---@param index number
--- The index of the display that changed orientation.
---@param orientation LoveWindowDisplayOrientation
--- The new orientation.
function love.displayrotated(index, orientation) end

--- Callback function used to draw on the screen every frame.
function love.draw() end

--- The error handler, used to display error messages.
---@param msg string
--- The error message.
---@return function
--- Function which handles one frame, including events and rendering, when called...
function love.errorhandler(msg) end

--- Callback function triggered when a file is dragged and dropped onto the window.
---@param file LoveFilesystemDroppedFile
--- The unopened File object representing the file that was dropped.
function love.filedropped(file) end

--- Callback function triggered when window receives or loses focus.
---@param focus boolean
--- True if the window gains focus, false if it loses focus.
function love.focus(focus) end

--- Called when a Joystick's virtual gamepad axis is moved.
---@param joystick LoveJoystickJoystick
--- The joystick object.
---@param axis LoveJoystickGamepadAxis
--- The virtual gamepad axis.
---@param value number
--- The new axis value.
function love.gamepadaxis(joystick, axis, value) end

--- Called when a Joystick's virtual gamepad button is pressed.
---@param joystick LoveJoystickJoystick
--- The joystick object.
---@param button LoveJoystickGamepadButton
--- The virtual gamepad button.
function love.gamepadpressed(joystick, button) end

--- Called when a Joystick's virtual gamepad button is released.
---@param joystick LoveJoystickJoystick
--- The joystick object.
---@param button LoveJoystickGamepadButton
--- The virtual gamepad button.
function love.gamepadreleased(joystick, button) end

--- Called when a Joystick is connected.
---@param joystick LoveJoystickJoystick
--- The newly connected Joystick object.
function love.joystickadded(joystick) end

--- Called when a joystick axis moves.
---@param joystick LoveJoystickJoystick
--- The joystick object.
---@param axis number
--- The axis number.
---@param value number
--- The new axis value.
function love.joystickaxis(joystick, axis, value) end

--- Called when a joystick hat direction changes.
---@param joystick LoveJoystickJoystick
--- The joystick object.
---@param hat number
--- The hat number.
---@param direction LoveJoystickJoystickHat
--- The new hat direction.
function love.joystickhat(joystick, hat, direction) end

--- Called when a joystick button is pressed.
---@param joystick LoveJoystickJoystick
--- The joystick object.
---@param button number
--- The button number.
function love.joystickpressed(joystick, button) end

--- Called when a joystick button is released.
---@param joystick LoveJoystickJoystick
--- The joystick object.
---@param button number
--- The button number.
function love.joystickreleased(joystick, button) end

--- Called when a Joystick is disconnected.
---@param joystick LoveJoystickJoystick
--- The now-disconnected Joystick object.
function love.joystickremoved(joystick) end

--- Callback function triggered when a key is pressed.
---@param key LoveKeyboardKeyConstant
--- Character of the pressed key.
---@param scancode LoveKeyboardScancode
--- The scancode representing the pressed key.
---@param isrepeat boolean
--- Whether this keypress event is a repeat. The delay between key repeats depend...
---@overload fun(LoveKeyboardKeyConstant, boolean)
function love.keypressed(key, scancode, isrepeat) end

--- Callback function triggered when a keyboard key is released.
---@param key LoveKeyboardKeyConstant
--- Character of the released key.
---@param scancode LoveKeyboardScancode
--- The scancode representing the released key.
function love.keyreleased(key, scancode) end

--- This function is called exactly once at the beginning of the game.
---@param arg table
--- Command-line arguments given to the game.
---@param unfilteredArg table
--- Unfiltered command-line arguments given to the executable (see #Notes).
function love.load(arg, unfilteredArg) end

--- Callback function triggered when the system is running out of memory on mobile devices. Mobile op...
function love.lowmemory() end

--- Callback function triggered when window receives or loses mouse focus.
---@param focus boolean
--- Whether the window has mouse focus or not.
function love.mousefocus(focus) end

--- Callback function triggered when the mouse is moved.
---@param x number
--- The mouse position on the x-axis.
---@param y number
--- The mouse position on the y-axis.
---@param dx number
--- The amount moved along the x-axis since the last time love.mousemoved was cal...
---@param dy number
--- The amount moved along the y-axis since the last time love.mousemoved was cal...
---@param istouch boolean
--- True if the mouse button press originated from a touchscreen touch-press.
function love.mousemoved(x, y, dx, dy, istouch) end

--- Callback function triggered when a mouse button is pressed.
---@param x number
--- Mouse x position, in pixels.
---@param y number
--- Mouse y position, in pixels.
---@param button number
--- The button index that was pressed. 1 is the primary mouse button, 2 is the se...
---@param istouch boolean
--- True if the mouse button press originated from a touchscreen touch-press.
---@param presses number
--- The number of presses in a short time frame and small area, used to simulate ...
function love.mousepressed(x, y, button, istouch, presses) end

--- Callback function triggered when a mouse button is released.
---@param x number
--- Mouse x position, in pixels.
---@param y number
--- Mouse y position, in pixels.
---@param button number
--- The button index that was released. 1 is the primary mouse button, 2 is the s...
---@param istouch boolean
--- True if the mouse button release originated from a touchscreen touch-release.
---@param presses number
--- The number of presses in a short time frame and small area, used to simulate ...
function love.mousereleased(x, y, button, istouch, presses) end

--- Callback function triggered when the game is closed.
---@return boolean
--- Abort quitting. If true, do not close the game.
function love.quit() end

--- Called when the window is resized, for example if the user resizes the window, or if love.window....
---@param w number
--- The new width.
---@param h number
--- The new height.
function love.resize(w, h) end

--- The main function, containing the main loop. A sensible default is used when left out.
---@return function
--- Function which handlers one frame, including events and rendering when called.
function love.run() end

--- Called when the candidate text for an IME (Input Method Editor) has changed. The candidate text i...
---@param text string
--- The UTF-8 encoded unicode candidate text.
---@param start number
--- The start cursor of the selected candidate text.
---@param length number
--- The length of the selected candidate text. May be 0.
function love.textedited(text, start, length) end

--- Called when text has been entered by the user. For example if shift-2 is pressed on an American k...
---@param text string
--- The UTF-8 encoded unicode text.
function love.textinput(text) end

--- Callback function triggered when a Thread encounters an error.
---@param thread LoveThreadThread
--- The thread which produced the error.
---@param errorstr string
--- The error message.
function love.threaderror(thread, errorstr) end

--- Callback function triggered when a touch press moves inside the touch screen.
---@param id any
--- [light userdata] The identifier for the touch press.
---@param x number
--- The x-axis position of the touch inside the window, in pixels.
---@param y number
--- The y-axis position of the touch inside the window, in pixels.
---@param dx number
--- The x-axis movement of the touch inside the window, in pixels.
---@param dy number
--- The y-axis movement of the touch inside the window, in pixels.
---@param pressure number
--- The amount of pressure being applied. Most touch screens aren't pressure sens...
function love.touchmoved(id, x, y, dx, dy, pressure) end

--- Callback function triggered when the touch screen is touched.
---@param id any
--- [light userdata] The identifier for the touch press.
---@param x number
--- The x-axis position of the touch press inside the window, in pixels.
---@param y number
--- The y-axis position of the touch press inside the window, in pixels.
---@param dx number
--- The x-axis movement of the touch press inside the window, in pixels. This sho...
---@param dy number
--- The y-axis movement of the touch press inside the window, in pixels. This sho...
---@param pressure number
--- The amount of pressure being applied. Most touch screens aren't pressure sens...
function love.touchpressed(id, x, y, dx, dy, pressure) end

--- Callback function triggered when the touch screen stops being touched.
---@param id any
--- [light userdata] The identifier for the touch press.
---@param x number
--- The x-axis position of the touch inside the window, in pixels.
---@param y number
--- The y-axis position of the touch inside the window, in pixels.
---@param dx number
--- The x-axis movement of the touch inside the window, in pixels.
---@param dy number
--- The y-axis movement of the touch inside the window, in pixels.
---@param pressure number
--- The amount of pressure being applied. Most touch screens aren't pressure sens...
function love.touchreleased(id, x, y, dx, dy, pressure) end

--- Callback function used to update the state of the game every frame.
---@param dt number
--- Time since the last update in seconds.
function love.update(dt) end

--- Callback function triggered when window is minimized/hidden or unminimized by the user.
---@param visible boolean
--- True if the window is visible, false if it isn't.
function love.visible(visible) end

--- Callback function triggered when the mouse wheel is moved.
---@param x number
--- Amount of horizontal mouse wheel movement. Positive values indicate movement ...
---@param y number
--- Amount of vertical mouse wheel movement. Positive values indicate upward move...
function love.wheelmoved(x, y) end

--- ------------------------------------------------------------
--- love.audio
--- Provides an interface to create noise with the user's speakers.
---@class love.audio
love.audio = {}

--- The different distance models. Extended information can be found in the chapter "3.4. Attenuation...
---@alias LoveAudioDistanceModel
---| 'none' # Sources do not get attenuated.
---| 'inverse' # Inverse distance attenuation.
---| 'inverseclamped' # Inverse distance attenuation. Gain is clamped. In version 0.9.2 and...
---| 'linear' # Linear attenuation.
---| 'linearclamped' # Linear attenuation. Gain is clamped. In version 0.9.2 and older thi...
---| 'exponent' # Exponential attenuation.
---| 'exponentclamped' # Exponential attenuation. Gain is clamped. In version 0.9.2 and olde...

--- The different types of effects supported by love.audio.setEffect.
---@alias LoveAudioEffectType
---| 'chorus' # Plays multiple copies of the sound with slight pitch and time varia...
---| 'compressor' # Decreases the dynamic range of the sound, making the loud and quiet...
---| 'distortion' # Alters the sound by amplifying it until it clips, shearing off part...
---| 'echo' # Decaying feedback based effect, on the order of seconds. Also known...
---| 'equalizer' # Adjust the frequency components of the sound using a 4-band (low-sh...
---| 'flanger' # Plays two copies of the sound; while varying the phase, or equivale...
---| 'reverb' # Decaying feedback based effect, on the order of milliseconds. Used ...
---| 'ringmodulator' # An implementation of amplitude modulation; multiplies the source si...

--- The different types of waveforms that can be used with the '''ringmodulator''' EffectType.
---@alias LoveAudioEffectWaveform
---| 'sawtooth' # A sawtooth wave, also known as a ramp wave. Named for its linear ri...
---| 'sine' # A sine wave. Follows a trigonometric sine function.
---| 'square' # A square wave. Switches between high and low states (near-)instanta...
---| 'triangle' # A triangle wave. Follows a linear rise and fall that repeats period...

--- Types of filters for Sources.
---@alias LoveAudioFilterType
---| 'lowpass' # Low-pass filter. High frequency sounds are attenuated.
---| 'highpass' # High-pass filter. Low frequency sounds are attenuated.
---| 'bandpass' # Band-pass filter. Both high and low frequency sounds are attenuated...

--- Types of audio sources. A good rule of thumb is to use stream for music files and static for all ...
---@alias LoveAudioSourceType
---| 'static' # The whole audio is decoded.
---| 'stream' # The audio is decoded in chunks when needed.
---| 'queue' # The audio must be manually queued by the user.

--- Units that represent time.
---@alias LoveAudioTimeUnit
---| 'seconds' # Regular seconds.
---| 'samples' # Audio samples.

--- Represents an audio input device capable of recording sounds.
---@class LoveAudioRecordingDevice
LoveAudioRecordingDevice = {}

--- Gets the number of bits per sample in the data currently being recorded.
---@return number
--- The number of bits per sample in the data that's currently being recorded.
function LoveAudioRecordingDevice:getBitDepth() end

--- Gets the number of channels currently being recorded (mono or stereo).
---@return number
--- The number of channels being recorded (1 for mono, 2 for stereo).
function LoveAudioRecordingDevice:getChannelCount() end

--- Gets all recorded audio SoundData stored in the device's internal ring buffer. The internal ring ...
---@return LoveSoundSoundData
--- The recorded audio data, or nil if the device isn't recording.
function LoveAudioRecordingDevice:getData() end

--- Gets the name of the recording device.
---@return string
--- The name of the device.
function LoveAudioRecordingDevice:getName() end

--- Gets the number of currently recorded samples.
---@return number
--- The number of samples that have been recorded so far.
function LoveAudioRecordingDevice:getSampleCount() end

--- Gets the number of samples per second currently being recorded.
---@return number
--- The number of samples being recorded per second (sample rate).
function LoveAudioRecordingDevice:getSampleRate() end

--- Gets whether the device is currently recording.
---@return boolean
--- True if the recording, false otherwise.
function LoveAudioRecordingDevice:isRecording() end

--- Begins recording audio using this device.
---@param samplecount number
--- The maximum number of samples to store in an internal ring buffer when record...
---@param samplerate? number
--- The number of samples per second to store when recording.
---@param bitdepth? number
--- The number of bits per sample.
---@param channels? number
--- Whether to record in mono or stereo. Most microphones don't support more than...
---@return boolean
--- True if the device successfully began recording using the specified parameter...
function LoveAudioRecordingDevice:start(samplecount, samplerate, bitdepth, channels) end

--- Stops recording audio from this device. Any sound data currently in the device's buffer will be r...
---@return LoveSoundSoundData
--- The sound data currently in the device's buffer, or nil if the device wasn't ...
function LoveAudioRecordingDevice:stop() end

--- A Source represents audio you can play back. You can do interesting things with Sources, like set...
---@class LoveAudioSource
LoveAudioSource = {}

--- Creates an identical copy of the Source in the stopped state. Static Sources will use significant...
---@return LoveAudioSource
--- The new identical copy of this Source.
function LoveAudioSource:clone() end

--- Gets a list of the Source's active effect names.
---@return table
--- A list of the source's active effect names.
function LoveAudioSource:getActiveEffects() end

--- Gets the amount of air absorption applied to the Source. By default the value is set to 0 which m...
---@return number
--- The amount of air absorption applied to the Source.
function LoveAudioSource:getAirAbsorption() end

--- Gets the reference and maximum attenuation distances of the Source. The values, combined with the...
---@return number
--- The current reference attenuation distance. If the current DistanceModel is c...
---@return number
--- The current maximum attenuation distance.
function LoveAudioSource:getAttenuationDistances() end

--- Gets the number of channels in the Source. Only 1-channel (mono) Sources can use directional and ...
---@return number
--- 1 for mono, 2 for stereo.
function LoveAudioSource:getChannelCount() end

--- Gets the Source's directional volume cones. Together with Source:setDirection, the cone angles al...
---@return number
--- The inner angle from the Source's direction, in radians. The Source will play...
---@return number
--- The outer angle from the Source's direction, in radians. The Source will play...
---@return number
--- The Source's volume when the listener is outside both the inner and outer con...
function LoveAudioSource:getCone() end

--- Gets the direction of the Source.
---@return number
--- The X part of the direction vector.
---@return number
--- The Y part of the direction vector.
---@return number
--- The Z part of the direction vector.
function LoveAudioSource:getDirection() end

--- Gets the duration of the Source. For streaming Sources it may not always be sample-accurate, and ...
---@param unit? LoveAudioTimeUnit
--- The time unit for the return value.
---@return number
--- The duration of the Source, or -1 if it cannot be determined.
function LoveAudioSource:getDuration(unit) end

--- Gets the filter settings associated to a specific effect. This function returns nil if the effect...
---@param name string
--- The name of the effect.
---@param filtersettings? table
--- An optional empty table that will be filled with the filter settings.
---@return table
--- The settings for the filter associated to this effect, or nil if the effect i...
function LoveAudioSource:getEffect(name, filtersettings) end

--- Gets the filter settings currently applied to the Source.
---@return table
--- The filter settings to use for this Source, or nil if the Source has no activ...
function LoveAudioSource:getFilter() end

--- Gets the number of free buffer slots in a queueable Source. If the queueable Source is playing, t...
---@return number
--- How many more SoundData objects can be queued up.
function LoveAudioSource:getFreeBufferCount() end

--- Gets the current pitch of the Source.
---@return number
--- The pitch, where 1.0 is normal.
function LoveAudioSource:getPitch() end

--- Gets the position of the Source.
---@return number
--- The X position of the Source.
---@return number
--- The Y position of the Source.
---@return number
--- The Z position of the Source.
function LoveAudioSource:getPosition() end

--- Returns the rolloff factor of the source.
---@return number
--- The rolloff factor.
function LoveAudioSource:getRolloff() end

--- Gets the type of the Source.
---@return LoveAudioSourceType
--- The type of the source.
function LoveAudioSource:getType() end

--- Gets the velocity of the Source.
---@return number
--- The X part of the velocity vector.
---@return number
--- The Y part of the velocity vector.
---@return number
--- The Z part of the velocity vector.
function LoveAudioSource:getVelocity() end

--- Gets the current volume of the Source.
---@return number
--- The volume of the Source, where 1.0 is normal volume.
function LoveAudioSource:getVolume() end

--- Returns the volume limits of the source.
---@return number
--- The minimum volume.
---@return number
--- The maximum volume.
function LoveAudioSource:getVolumeLimits() end

--- Returns whether the Source will loop.
---@return boolean
--- True if the Source will loop, false otherwise.
function LoveAudioSource:isLooping() end

--- Returns whether the Source is playing.
---@return boolean
--- True if the Source is playing, false otherwise.
function LoveAudioSource:isPlaying() end

--- Gets whether the Source's position, velocity, direction, and cone angles are relative to the list...
---@return boolean
--- True if the position, velocity, direction and cone angles are relative to the...
function LoveAudioSource:isRelative() end

--- Pauses the Source.
function LoveAudioSource:pause() end

--- Starts playing the Source.
---@return boolean
--- Whether the Source was able to successfully start playing.
function LoveAudioSource:play() end

--- Queues SoundData for playback in a queueable Source. This method requires the Source to be create...
---@param sounddata LoveSoundSoundData
--- The data to queue. The SoundData's sample rate, bit depth, and channel count ...
---@return boolean
--- True if the data was successfully queued for playback, false if there were no...
function LoveAudioSource:queue(sounddata) end

--- Sets the currently playing position of the Source.
---@param offset number
--- The position to seek to.
---@param unit? LoveAudioTimeUnit
--- The unit of the position value.
function LoveAudioSource:seek(offset, unit) end

--- Sets the amount of air absorption applied to the Source. By default the value is set to 0 which m...
---@param amount number
--- The amount of air absorption applied to the Source. Must be between 0 and 10.
function LoveAudioSource:setAirAbsorption(amount) end

--- Sets the reference and maximum attenuation distances of the Source. The parameters, combined with...
---@param ref number
--- The new reference attenuation distance. If the current DistanceModel is clamp...
---@param max number
--- The new maximum attenuation distance.
function LoveAudioSource:setAttenuationDistances(ref, max) end

--- Sets the Source's directional volume cones. Together with Source:setDirection, the cone angles al...
---@param innerAngle number
--- The inner angle from the Source's direction, in radians. The Source will play...
---@param outerAngle number
--- The outer angle from the Source's direction, in radians. The Source will play...
---@param outerVolume? number
--- The Source's volume when the listener is outside both the inner and outer con...
function LoveAudioSource:setCone(innerAngle, outerAngle, outerVolume) end

--- Sets the direction vector of the Source. A zero vector makes the source non-directional.
---@param x number
--- The X part of the direction vector.
---@param y number
--- The Y part of the direction vector.
---@param z number
--- The Z part of the direction vector.
function LoveAudioSource:setDirection(x, y, z) end

--- Applies an audio effect to the Source. The effect must have been previously defined using love.au...
---@param name string
--- The name of the effect previously set up with love.audio.setEffect.
---@param enable? boolean
--- If false and the given effect name was previously enabled on this Source, dis...
---@return boolean
--- Whether the effect was successfully applied to this Source.
function LoveAudioSource:setEffect(name, enable) end

--- Sets a low-pass, high-pass, or band-pass filter to apply when playing the Source.
---@param settings table
--- The filter settings to use for this Source, with the following fields:
---@overload fun()
---@return boolean
--- Whether the filter was successfully applied to the Source.
function LoveAudioSource:setFilter(settings) end

--- Sets whether the Source should loop.
---@param loop boolean
--- True if the source should loop, false otherwise.
function LoveAudioSource:setLooping(loop) end

--- Sets the pitch of the Source.
---@param pitch number
--- Calculated with regard to 1 being the base pitch. Each reduction by 50 percen...
function LoveAudioSource:setPitch(pitch) end

--- Sets the position of the Source. Please note that this only works for mono (i.e. non-stereo) soun...
---@param x number
--- The X position of the Source.
---@param y number
--- The Y position of the Source.
---@param z number
--- The Z position of the Source.
function LoveAudioSource:setPosition(x, y, z) end

--- Sets whether the Source's position, velocity, direction, and cone angles are relative to the list...
---@param enable? boolean
--- True to make the position, velocity, direction and cone angles relative to th...
function LoveAudioSource:setRelative(enable) end

--- Sets the rolloff factor which affects the strength of the used distance attenuation. Extended inf...
---@param rolloff number
--- The new rolloff factor.
function LoveAudioSource:setRolloff(rolloff) end

--- Sets the velocity of the Source. This does '''not''' change the position of the Source, but lets ...
---@param x number
--- The X part of the velocity vector.
---@param y number
--- The Y part of the velocity vector.
---@param z number
--- The Z part of the velocity vector.
function LoveAudioSource:setVelocity(x, y, z) end

--- Sets the current volume of the Source.
---@param volume number
--- The volume for a Source, where 1.0 is normal volume. Volume cannot be raised ...
function LoveAudioSource:setVolume(volume) end

--- Sets the volume limits of the source. The limits have to be numbers from 0 to 1.
---@param min number
--- The minimum volume.
---@param max number
--- The maximum volume.
function LoveAudioSource:setVolumeLimits(min, max) end

--- Stops a Source.
function LoveAudioSource:stop() end

--- Gets the currently playing position of the Source.
---@param unit? LoveAudioTimeUnit
--- The type of unit for the return value.
---@return number
--- The currently playing position of the Source.
function LoveAudioSource:tell(unit) end

--- Gets a list of the names of the currently enabled effects.
---@return table
--- The list of the names of the currently enabled effects.
function love.audio.getActiveEffects() end

--- Gets the current number of simultaneously playing sources.
---@return number
--- The current number of simultaneously playing sources.
function love.audio.getActiveSourceCount() end

--- Returns the distance attenuation model.
---@return LoveAudioDistanceModel
--- The current distance model. The default is 'inverseclamped'.
function love.audio.getDistanceModel() end

--- Gets the current global scale factor for velocity-based doppler effects.
---@return number
--- The current doppler scale factor.
function love.audio.getDopplerScale() end

--- Gets the settings associated with an effect.
---@param name string
--- The name of the effect.
---@return table
--- The settings associated with the effect.
function love.audio.getEffect(name) end

--- Gets the maximum number of active effects supported by the system.
---@return number
--- The maximum number of active effects.
function love.audio.getMaxSceneEffects() end

--- Gets the maximum number of active Effects in a single Source object, that the system can support.
---@return number
--- The maximum number of active Effects per Source.
function love.audio.getMaxSourceEffects() end

--- Returns the orientation of the listener.
---@return number
--- Forward x of the listener orientation.
---@return number
--- Forward y of the listener orientation.
---@return number
--- Forward z of the listener orientation.
---@return number
--- Up x of the listener orientation.
---@return number
--- Up y of the listener orientation.
---@return number
--- Up z of the listener orientation.
function love.audio.getOrientation() end

--- Returns the position of the listener. Please note that positional audio only works for mono (i.e....
---@return number
--- The X position of the listener.
---@return number
--- The Y position of the listener.
---@return number
--- The Z position of the listener.
function love.audio.getPosition() end

--- Gets a list of RecordingDevices on the system. The first device in the list is the user's default...
---@return table
--- The list of connected recording devices.
function love.audio.getRecordingDevices() end

--- Returns the velocity of the listener.
---@return number
--- The X velocity of the listener.
---@return number
--- The Y velocity of the listener.
---@return number
--- The Z velocity of the listener.
function love.audio.getVelocity() end

--- Returns the master volume.
---@return number
--- The current master volume
function love.audio.getVolume() end

--- Gets whether audio effects are supported in the system.
---@return boolean
--- True if effects are supported, false otherwise.
function love.audio.isEffectsSupported() end

--- Creates a new Source usable for real-time generated sound playback with Source:queue.
---@param samplerate number
--- Number of samples per second when playing.
---@param bitdepth number
--- Bits per sample (8 or 16).
---@param channels number
--- 1 for mono or 2 for stereo.
---@param buffercount? number
--- The number of buffers that can be queued up at any given time with Source:que...
---@return LoveAudioSource
--- The new Source usable with Source:queue.
function love.audio.newQueueableSource(samplerate, bitdepth, channels, buffercount) end

--- Creates a new Source from a filepath, File, Decoder or SoundData. Sources created from SoundData ...
---@param filename string
--- The filepath to the audio file.
---@param type LoveAudioSourceType
--- Streaming or static source.
---@overload fun(LoveSoundSoundData)
---@return LoveAudioSource
--- A new Source that can play the specified audio.
function love.audio.newSource(filename, type) end

--- Pauses specific or all currently played Sources.
---@param source LoveAudioSource
--- The first Source to pause.
---@param ___ LoveAudioSource
--- Additional Sources to pause.
---@overload fun()
---@overload fun(table)
function love.audio.pause(source, ___) end

--- Plays the specified Source.
---@param source1 LoveAudioSource
--- The first Source to play.
---@param source2 LoveAudioSource
--- The second Source to play.
---@param ___ LoveAudioSource
--- Additional Sources to play.
---@overload fun(LoveAudioSource)
function love.audio.play(source1, source2, ___) end

--- Sets the distance attenuation model.
---@param model LoveAudioDistanceModel
--- The new distance model.
function love.audio.setDistanceModel(model) end

--- Sets a global scale factor for velocity-based doppler effects. The default scale value is 1.
---@param scale number
--- The new doppler scale factor. The scale must be greater than 0.
function love.audio.setDopplerScale(scale) end

--- Defines an effect that can be applied to a Source. Not all system supports audio effects. Use lov...
---@param name string
--- The name of the effect.
---@param settings table
--- The settings to use for this effect, with the following fields:
---@return boolean
--- Whether the effect was successfully created.
function love.audio.setEffect(name, settings) end

--- Sets whether the system should mix the audio with the system's audio.
---@param mix boolean
--- True to enable mixing, false to disable it.
---@return boolean
--- True if the change succeeded, false otherwise.
function love.audio.setMixWithSystem(mix) end

--- Sets the orientation of the listener.
---@param fx__fy__fz number
--- Forward vector of the listener orientation.
---@param ux__uy__uz number
--- Up vector of the listener orientation.
function love.audio.setOrientation(fx__fy__fz, ux__uy__uz) end

--- Sets the position of the listener, which determines how sounds play.
---@param x number
--- The x position of the listener.
---@param y number
--- The y position of the listener.
---@param z number
--- The z position of the listener.
function love.audio.setPosition(x, y, z) end

--- Sets the velocity of the listener.
---@param x number
--- The X velocity of the listener.
---@param y number
--- The Y velocity of the listener.
---@param z number
--- The Z velocity of the listener.
function love.audio.setVelocity(x, y, z) end

--- Sets the master volume.
---@param volume number
--- 1.0 is max and 0.0 is off.
function love.audio.setVolume(volume) end

--- Stops currently played sources.
---@param source1 LoveAudioSource
--- The first Source to stop.
---@param source2 LoveAudioSource
--- The second Source to stop.
---@param ___ LoveAudioSource
--- Additional Sources to stop.
---@overload fun()
---@overload fun(LoveAudioSource)
function love.audio.stop(source1, source2, ___) end

--- ------------------------------------------------------------
--- love.data
--- Provides functionality for creating and transforming data.
---@class love.data
love.data = {}

--- Compressed data formats.
---@alias LoveDataCompressedDataFormat
---| 'lz4' # The LZ4 compression format. Compresses and decompresses very quickl...
---| 'zlib' # The zlib format is DEFLATE-compressed data with a small bit of head...
---| 'gzip' # The gzip format is DEFLATE-compressed data with a slightly larger h...
---| 'deflate' # Raw DEFLATE-compressed data (no header).

--- Return type of various data-returning functions.
---@alias LoveDataContainerType
---| 'data' # Return type is ByteData.
---| 'string' # Return type is string.

--- Encoding format used to encode or decode data.
---@alias LoveDataEncodeFormat
---| 'base64' # Encode/decode data as base64 binary-to-text encoding.
---| 'hex' # Encode/decode data as hexadecimal string.

--- Hash algorithm of love.data.hash.
---@alias LoveDataHashFunction
---| 'md5' # MD5 hash algorithm (16 bytes).
---| 'sha1' # SHA1 hash algorithm (20 bytes).
---| 'sha224' # SHA2 hash algorithm with message digest size of 224 bits (28 bytes).
---| 'sha256' # SHA2 hash algorithm with message digest size of 256 bits (32 bytes).
---| 'sha384' # SHA2 hash algorithm with message digest size of 384 bits (48 bytes).
---| 'sha512' # SHA2 hash algorithm with message digest size of 512 bits (64 bytes).

--- Data object containing arbitrary bytes in an contiguous memory. There are currently no LÖVE func...
---@class LoveDataByteData
--- (also inherits: Data)
--- Represents byte data compressed using a specific algorithm. love.data.decompress can be used to d...
---@class LoveDataCompressedData
--- (also inherits: Object)
LoveDataCompressedData = {}

--- Gets the compression format of the CompressedData.
---@return LoveDataCompressedDataFormat
--- The format of the CompressedData.
function LoveDataCompressedData:getFormat() end

--- Compresses a string or data using a specific compression algorithm.
---@param container LoveDataContainerType
--- What type to return the compressed data as.
---@param format LoveDataCompressedDataFormat
--- The format to use when compressing the string.
---@param rawstring string
--- The raw (un-compressed) string to compress.
---@param level? number
--- The level of compression to use, between 0 and 9. -1 indicates the default le...
---@return any
--- CompressedData/string which contains the compressed version of rawstring.
function love.data.compress(container, format, rawstring, level) end

--- Decode Data or a string from any of the EncodeFormats to Data or string.
---@param container LoveDataContainerType
--- What type to return the decoded data as.
---@param format LoveDataEncodeFormat
--- The format of the input data.
---@param sourceString string
--- The raw (encoded) data to decode.
---@return any
--- ByteData/string which contains the decoded version of source.
function love.data.decode(container, format, sourceString) end

--- Decompresses a CompressedData or previously compressed string or Data object.
---@param container LoveDataContainerType
--- What type to return the decompressed data as.
---@param format LoveDataCompressedDataFormat
--- The format that was used to compress the given string.
---@param compressedString string
--- A string containing data previously compressed with love.data.compress.
---@overload fun(LoveDataContainerType, LoveDataCompressedData)
---@return any
--- Data/string containing the raw decompressed data.
function love.data.decompress(container, format, compressedString) end

--- Encode Data or a string to a Data or string in one of the EncodeFormats.
---@param container LoveDataContainerType
--- What type to return the encoded data as.
---@param format LoveDataEncodeFormat
--- The format of the output data.
---@param sourceString string
--- The raw data to encode.
---@param linelength? number
--- The maximum line length of the output. Only supported for base64, ignored if 0.
---@return any
--- ByteData/string which contains the encoded version of source.
function love.data.encode(container, format, sourceString, linelength) end

--- Gets the size in bytes that a given format used with love.data.pack will use. This function behav...
---@param format string
--- A string determining how the values are packed. Follows the rules of Lua 5.3'...
---@return number
--- The size in bytes that the packed data will use.
function love.data.getPackedSize(format) end

--- Compute the message digest of a string using a specified hash algorithm.
---@param hashFunction LoveDataHashFunction
--- Hash algorithm to use.
---@param string string
--- String to hash.
---@return string
--- Raw message digest string.
function love.data.hash(hashFunction, string) end

--- Creates a new Data object containing arbitrary bytes. Data:getPointer along with LuaJIT's FFI can...
---@param Data any
--- [Data] The existing Data object to copy.
---@param offset? number
--- The offset of the subsection to copy, in bytes.
---@param size? number
--- The size in bytes of the new Data object.
---@overload fun(string)
---@return LoveDataByteData
--- The new Data object.
function love.data.newByteData(Data, offset, size) end

--- Creates a new Data referencing a subsection of an existing Data object.
---@param data any
--- [Data] The Data object to reference.
---@param offset number
--- The offset of the subsection to reference, in bytes.
---@param size number
--- The size in bytes of the subsection to reference.
---@return any
--- The new Data view.
function love.data.newDataView(data, offset, size) end

--- Packs (serializes) simple Lua values. This function behaves the same as Lua 5.3's string.pack.
---@param container LoveDataContainerType
--- What type to return the encoded data as.
---@param format string
--- A string determining how the values are packed. Follows the rules of Lua 5.3'...
---@param v1 any
--- [number or boolean or string] The first value (number, boolean, or string) to serialize.
---@param ___ any
--- [number or boolean or string] Additional values to serialize.
---@return any
--- Data/string which contains the serialized data.
function love.data.pack(container, format, v1, ___) end

--- Unpacks (deserializes) a byte-string or Data into simple Lua values. This function behaves the sa...
---@param format string
--- A string determining how the values were packed. Follows the rules of Lua 5.3...
---@param datastring string
--- A string containing the packed (serialized) data.
---@param pos? number
--- Where to start reading in the string. Negative values can be used to read rel...
---@return any
--- The first value (number, boolean, or string) that was unpacked.
---@return any
--- Additional unpacked values.
---@return number
--- The index of the first unread byte in the data string.
function love.data.unpack(format, datastring, pos) end

--- ------------------------------------------------------------
--- love.event
--- Manages events, like keypresses.
---@class love.event
love.event = {}

--- Arguments to love.event.push() and the like. Since 0.8.0, event names are no longer abbreviated.
---@alias LoveEventEvent
---| 'focus' # Window focus gained or lost
---| 'joystickpressed' # Joystick pressed
---| 'joystickreleased' # Joystick released
---| 'keypressed' # Key pressed
---| 'keyreleased' # Key released
---| 'mousepressed' # Mouse pressed
---| 'mousereleased' # Mouse released
---| 'quit' # Quit
---| 'resize' # Window size changed by the user
---| 'visible' # Window is minimized or un-minimized by the user
---| 'mousefocus' # Window mouse focus gained or lost
---| 'threaderror' # A Lua error has occurred in a thread
---| 'joystickadded' # Joystick connected
---| 'joystickremoved' # Joystick disconnected
---| 'joystickaxis' # Joystick axis motion
---| 'joystickhat' # Joystick hat pressed
---| 'gamepadpressed' # Joystick's virtual gamepad button pressed
---| 'gamepadreleased' # Joystick's virtual gamepad button released
---| 'gamepadaxis' # Joystick's virtual gamepad axis moved
---| 'textinput' # User entered text
---| 'mousemoved' # Mouse position changed
---| 'lowmemory' # Running out of memory on mobile devices system
---| 'textedited' # Candidate text for an IME changed
---| 'wheelmoved' # Mouse wheel moved
---| 'touchpressed' # Touch screen touched
---| 'touchreleased' # Touch screen stop touching
---| 'touchmoved' # Touch press moved inside touch screen
---| 'directorydropped' # Directory is dragged and dropped onto the window
---| 'filedropped' # File is dragged and dropped onto the window.
---| 'jp' # Joystick pressed
---| 'jr' # Joystick released
---| 'kp' # Key pressed
---| 'kr' # Key released
---| 'mp' # Mouse pressed
---| 'mr' # Mouse released
---| 'q' # Quit
---| 'f' # Window focus gained or lost

--- Clears the event queue.
function love.event.clear() end

--- Returns an iterator for messages in the event queue.
---@return function
--- Iterator function usable in a for loop.
function love.event.poll() end

--- Pump events into the event queue. This is a low-level function, and is usually not called by the ...
function love.event.pump() end

--- Adds an event to the event queue. From 0.10.0 onwards, you may pass an arbitrary amount of argume...
---@param n LoveEventEvent
--- The name of the event.
---@param a? any
--- First event argument.
---@param b? any
--- Second event argument.
---@param c? any
--- Third event argument.
---@param d? any
--- Fourth event argument.
---@param e? any
--- Fifth event argument.
---@param f? any
--- Sixth event argument.
---@param ___? any
--- Further event arguments may follow.
function love.event.push(n, a, b, c, d, e, f, ___) end

--- Adds the quit event to the queue. The quit event is a signal for the event handler to close LÖVE...
---@param exitstatus? number
--- The program exit status to use when closing the application.
function love.event.quit(exitstatus) end

--- Like love.event.poll(), but blocks until there is an event in the queue.
---@return LoveEventEvent
--- The name of event.
---@return any
--- First event argument.
---@return any
--- Second event argument.
---@return any
--- Third event argument.
---@return any
--- Fourth event argument.
---@return any
--- Fifth event argument.
---@return any
--- Sixth event argument.
---@return any
--- Further event arguments may follow.
function love.event.wait() end

--- ------------------------------------------------------------
--- love.filesystem
--- Provides an interface to the user's filesystem.
---@class love.filesystem
love.filesystem = {}

--- Buffer modes for File objects.
---@alias LoveFilesystemBufferMode
---| 'none' # No buffering. The result of write and append operations appears imm...
---| 'line' # Line buffering. Write and append operations are buffered until a ne...
---| 'full' # Full buffering. Write and append operations are always buffered unt...

--- How to decode a given FileData.
---@alias LoveFilesystemFileDecoder
---| 'file' # The data is unencoded.
---| 'base64' # The data is base64-encoded.

--- The different modes you can open a File in.
---@alias LoveFilesystemFileMode
---| 'r' # Open a file for read.
---| 'w' # Open a file for write.
---| 'a' # Open a file for append.
---| 'c' # Do not open a file (represents a closed file.)

--- The type of a file.
---@alias LoveFilesystemFileType
---| 'file' # Regular file.
---| 'directory' # Directory.
---| 'symlink' # Symbolic link.
---| 'other' # Something completely different like a device.

--- Represents a file dropped onto the window. Note that the DroppedFile type can only be obtained fr...
---@class LoveFilesystemDroppedFile : LoveFilesystemFile
--- (also inherits: Object)
--- Represents a file on the filesystem. A function that takes a file path can also take a File.
---@class LoveFilesystemFile
LoveFilesystemFile = {}

--- Closes a File.
---@return boolean
--- Whether closing was successful.
function LoveFilesystemFile:close() end

--- Flushes any buffered written data in the file to the disk.
---@return boolean
--- Whether the file successfully flushed any buffered data to the disk.
---@return string
--- The error string, if an error occurred and the file could not be flushed.
function LoveFilesystemFile:flush() end

--- Gets the buffer mode of a file.
---@return LoveFilesystemBufferMode
--- The current buffer mode of the file.
---@return number
--- The maximum size in bytes of the file's buffer.
function LoveFilesystemFile:getBuffer() end

--- Gets the filename that the File object was created with. If the file object originated from the l...
---@return string
--- The filename of the File.
function LoveFilesystemFile:getFilename() end

--- Gets the FileMode the file has been opened with.
---@return LoveFilesystemFileMode
--- The mode this file has been opened with.
function LoveFilesystemFile:getMode() end

--- Returns the file size.
---@return number
--- The file size in bytes.
function LoveFilesystemFile:getSize() end

--- Gets whether end-of-file has been reached.
---@return boolean
--- Whether EOF has been reached.
function LoveFilesystemFile:isEOF() end

--- Gets whether the file is open.
---@return boolean
--- True if the file is currently open, false otherwise.
function LoveFilesystemFile:isOpen() end

--- Iterate over all the lines in a file.
---@return function
--- The iterator (can be used in for loops).
function LoveFilesystemFile:lines() end

--- Open the file for write, read or append.
---@param mode LoveFilesystemFileMode
--- The mode to open the file in.
---@return boolean
--- True on success, false otherwise.
---@return string
--- The error string if an error occurred.
function LoveFilesystemFile:open(mode) end

--- Read a number of bytes from a file.
---@param container LoveDataContainerType
--- What type to return the file's contents as.
---@param bytes? number
--- The number of bytes to read.
---@overload fun(number?)
---@return any
--- FileData or string containing the read bytes.
---@return number
--- How many bytes have been read.
function LoveFilesystemFile:read(container, bytes) end

--- Seek to a position in a file
---@param pos number
--- The position to seek to
---@return boolean
--- Whether the operation was successful
function LoveFilesystemFile:seek(pos) end

--- Sets the buffer mode for a file opened for writing or appending. Files with buffering enabled wil...
---@param mode LoveFilesystemBufferMode
--- The buffer mode to use.
---@param size? number
--- The maximum size in bytes of the file's buffer.
---@return boolean
--- Whether the buffer mode was successfully set.
---@return string
--- The error string, if the buffer mode could not be set and an error occurred.
function LoveFilesystemFile:setBuffer(mode, size) end

--- Returns the position in the file.
---@return number
--- The current position.
function LoveFilesystemFile:tell() end

--- Write data to a file.
---@param data string
--- The string data to write.
---@param size? number
--- How many bytes to write.
---@return boolean
--- Whether the operation was successful.
---@return string
--- The error string if an error occurred.
function LoveFilesystemFile:write(data, size) end

--- Data representing the contents of a file.
---@class LoveFilesystemFileData
--- (also inherits: Object)
LoveFilesystemFileData = {}

--- Gets the extension of the FileData.
---@return string
--- The extension of the file the FileData represents.
function LoveFilesystemFileData:getExtension() end

--- Gets the filename of the FileData.
---@return string
--- The name of the file the FileData represents.
function LoveFilesystemFileData:getFilename() end

--- Append data to an existing file.
---@param name string
--- The name (and path) of the file.
---@param data string
--- The string data to append to the file.
---@param size? number
--- How many bytes to write.
---@return boolean
--- True if the operation was successful, or nil if there was an error.
---@return string
--- The error message on failure.
function love.filesystem.append(name, data, size) end

--- Gets whether love.filesystem follows symbolic links.
---@return boolean
--- Whether love.filesystem follows symbolic links.
function love.filesystem.areSymlinksEnabled() end

--- Recursively creates a directory. When called with 'a/b' it creates both 'a' and 'a/b', if they do...
---@param name string
--- The directory to create.
---@return boolean
--- True if the directory was created, false if not.
function love.filesystem.createDirectory(name) end

--- Returns the application data directory (could be the same as getUserDirectory)
---@return string
--- The path of the application data directory
function love.filesystem.getAppdataDirectory() end

--- Gets the filesystem paths that will be searched for c libraries when require is called. The paths...
---@return string
--- The paths that the ''require'' function will check for c libraries in love's ...
function love.filesystem.getCRequirePath() end

--- Returns a table with the names of files and subdirectories in the specified path. The table is no...
---@param dir string
--- The directory.
---@param callback function
--- A function which is called for each file and folder in the directory. The fil...
---@overload fun(string)
---@return table
--- A sequence with the names of all files and subdirectories as strings.
function love.filesystem.getDirectoryItems(dir, callback) end

--- Gets the write directory name for your game. Note that this only returns the name of the folder t...
---@return string
--- The identity that is used as write directory.
function love.filesystem.getIdentity() end

--- Gets information about the specified file or directory.
---@param path string
--- The file or directory path to check.
---@param filtertype LoveFilesystemFileType
--- Causes getInfo to only return the info table if the item at the given path ma...
---@param info table
--- A table which will be filled in with info about the specified path.
---@overload fun(string, LoveFilesystemFileType?)
---@return table
--- The table given as an argument, or nil if nothing exists at the path. The tab...
function love.filesystem.getInfo(path, filtertype, info) end

--- Gets the platform-specific absolute path of the directory containing a filepath. This can be used...
---@param filepath string
--- The filepath to get the directory of.
---@return string
--- The platform-specific full path of the directory containing the filepath.
function love.filesystem.getRealDirectory(filepath) end

--- Gets the filesystem paths that will be searched when require is called. The paths string returned...
---@return string
--- The paths that the ''require'' function will check in love's filesystem.
function love.filesystem.getRequirePath() end

--- Gets the full path to the designated save directory. This can be useful if you want to use the st...
---@return string
--- The absolute path to the save directory.
function love.filesystem.getSaveDirectory() end

--- Returns the full path to the the .love file or directory. If the game is fused to the LÖVE execu...
---@return string
--- The full platform-dependent path of the .love file or directory.
function love.filesystem.getSource() end

--- Returns the full path to the directory containing the .love file. If the game is fused to the LÖ...
---@return string
--- The full platform-dependent path of the directory containing the .love file.
function love.filesystem.getSourceBaseDirectory() end

--- Returns the path of the user's directory
---@return string
--- The path of the user's directory
function love.filesystem.getUserDirectory() end

--- Gets the current working directory.
---@return string
--- The current working directory.
function love.filesystem.getWorkingDirectory() end

--- Initializes love.filesystem, will be called internally, so should not be used explicitly.
---@param appname string
--- The name of the application binary, typically love.
function love.filesystem.init(appname) end

--- Gets whether the game is in fused mode or not. If a game is in fused mode, its save directory wil...
---@return boolean
--- True if the game is in fused mode, false otherwise.
function love.filesystem.isFused() end

--- Iterate over the lines in a file.
---@param name string
--- The name (and path) of the file
---@return function
--- A function that iterates over all the lines in the file
function love.filesystem.lines(name) end

--- Loads a Lua file (but does not run it).
---@param name string
--- The name (and path) of the file.
---@return function
--- The loaded chunk.
---@return string
--- The error message if file could not be opened.
function love.filesystem.load(name) end

--- Mounts a zip file or folder in the game's save directory for reading. It is also possible to moun...
---@param data any
--- [Data] The Data object in memory to mount.
---@param archivename string
--- The name to associate the mounted data with, for use with love.filesystem.unm...
---@param mountpoint string
--- The new path the archive will be mounted to.
---@param appendToPath? boolean
--- Whether the archive will be searched when reading a filepath before or after ...
---@overload fun(string, string, boolean?)
---@return boolean
--- True if the archive was successfully mounted, false otherwise.
function love.filesystem.mount(data, archivename, mountpoint, appendToPath) end

--- Creates a new File object. It needs to be opened before it can be accessed.
---@param filename string
--- The filename of the file.
---@param mode LoveFilesystemFileMode
--- The mode to open the file in.
---@overload fun(string)
---@return LoveFilesystemFile
--- The new File object, or nil if an error occurred.
---@return string
--- The error string if an error occurred.
function love.filesystem.newFile(filename, mode) end

--- Creates a new FileData object from a file on disk, or from a string in memory.
---@param contents string
--- The contents of the file in memory represented as a string.
---@param name string
--- The name of the file. The extension may be parsed and used by LÖVE when pass...
---@overload fun(string)
---@return LoveFilesystemFileData
--- The new FileData.
function love.filesystem.newFileData(contents, name) end

--- Read the contents of a file.
---@param container LoveDataContainerType
--- What type to return the file's contents as.
---@param name string
--- The name (and path) of the file
---@param size? number
--- How many bytes to read
---@overload fun(string, number?)
---@return any
--- FileData or string containing the file contents.
---@return number
--- How many bytes have been read.
---@return any
--- returns nil as content.
---@return string
--- returns an error message.
function love.filesystem.read(container, name, size) end

--- Removes a file or empty directory.
---@param name string
--- The file or directory to remove.
---@return boolean
--- True if the file/directory was removed, false otherwise.
function love.filesystem.remove(name) end

--- Sets the filesystem paths that will be searched for c libraries when require is called. The paths...
---@param paths string
--- The paths that the ''require'' function will check in love's filesystem.
function love.filesystem.setCRequirePath(paths) end

--- Sets the write directory for your game. Note that you can only set the name of the folder to stor...
---@param name string
--- The new identity that will be used as write directory.
function love.filesystem.setIdentity(name) end

--- Sets the filesystem paths that will be searched when require is called. The paths string given to...
---@param paths string
--- The paths that the ''require'' function will check in love's filesystem.
function love.filesystem.setRequirePath(paths) end

--- Sets the source of the game, where the code is present. This function can only be called once, an...
---@param path string
--- Absolute path to the game's source folder.
function love.filesystem.setSource(path) end

--- Sets whether love.filesystem follows symbolic links. It is enabled by default in version 0.10.0 a...
---@param enable boolean
--- Whether love.filesystem should follow symbolic links.
function love.filesystem.setSymlinksEnabled(enable) end

--- Unmounts a zip file or folder previously mounted for reading with love.filesystem.mount.
---@param archive string
--- The folder or zip file in the game's save directory which is currently mounted.
---@return boolean
--- True if the archive was successfully unmounted, false otherwise.
function love.filesystem.unmount(archive) end

--- Write data to a file in the save directory. If the file existed already, it will be completely re...
---@param name string
--- The name (and path) of the file.
---@param data string
--- The string data to write to the file.
---@param size? number
--- How many bytes to write.
---@return boolean
--- If the operation was successful.
---@return string
--- Error message if operation was unsuccessful.
function love.filesystem.write(name, data, size) end

--- ------------------------------------------------------------
--- love.font
--- Allows you to work with fonts.
---@class love.font
love.font = {}

--- True Type hinting mode.
---@alias LoveFontHintingMode
---| 'normal' # Default hinting. Should be preferred for typical antialiased fonts.
---| 'light' # Results in fuzzier text but can sometimes preserve the original gly...
---| 'mono' # Results in aliased / unsmoothed text with either full opacity or co...
---| 'none' # Disables hinting for the font. Results in fuzzier text.

--- A GlyphData represents a drawable symbol of a font Rasterizer.
---@class LoveFontGlyphData
--- (also inherits: Object)
LoveFontGlyphData = {}

--- Gets glyph advance.
---@return number
--- Glyph advance.
function LoveFontGlyphData:getAdvance() end

--- Gets glyph bearing.
---@return number
--- Glyph bearing X.
---@return number
--- Glyph bearing Y.
function LoveFontGlyphData:getBearing() end

--- Gets glyph bounding box.
---@return number
--- Glyph position x.
---@return number
--- Glyph position y.
---@return number
--- Glyph width.
---@return number
--- Glyph height.
function LoveFontGlyphData:getBoundingBox() end

--- Gets glyph dimensions.
---@return number
--- Glyph width.
---@return number
--- Glyph height.
function LoveFontGlyphData:getDimensions() end

--- Gets glyph pixel format.
---@return LoveImagePixelFormat
--- Glyph pixel format.
function LoveFontGlyphData:getFormat() end

--- Gets glyph number.
---@return number
--- Glyph number.
function LoveFontGlyphData:getGlyph() end

--- Gets glyph string.
---@return string
--- Glyph string.
function LoveFontGlyphData:getGlyphString() end

--- Gets glyph height.
---@return number
--- Glyph height.
function LoveFontGlyphData:getHeight() end

--- Gets glyph width.
---@return number
--- Glyph width.
function LoveFontGlyphData:getWidth() end

--- A Rasterizer handles font rendering, containing the font data (image or TrueType font) and drawab...
---@class LoveFontRasterizer
LoveFontRasterizer = {}

--- Gets font advance.
---@return number
--- Font advance.
function LoveFontRasterizer:getAdvance() end

--- Gets ascent height.
---@return number
--- Ascent height.
function LoveFontRasterizer:getAscent() end

--- Gets descent height.
---@return number
--- Descent height.
function LoveFontRasterizer:getDescent() end

--- Gets number of glyphs in font.
---@return number
--- Glyphs count.
function LoveFontRasterizer:getGlyphCount() end

--- Gets glyph data of a specified glyph.
---@param glyph string
--- Glyph
---@return LoveFontGlyphData
--- Glyph data
function LoveFontRasterizer:getGlyphData(glyph) end

--- Gets font height.
---@return number
--- Font height
function LoveFontRasterizer:getHeight() end

--- Gets line height of a font.
---@return number
--- Line height of a font.
function LoveFontRasterizer:getLineHeight() end

--- Checks if font contains specified glyphs.
---@param glyph1 any
--- [string or number] Glyph
---@param ___ any
--- [string or number] Additional glyphs
---@return boolean
--- Whatever font contains specified glyphs.
function LoveFontRasterizer:hasGlyphs(glyph1, ___) end

--- Creates a new BMFont Rasterizer.
---@param imageData LoveImageImageData
--- The image data containing the drawable pictures of font glyphs.
---@param glyphs string
--- The sequence of glyphs in the ImageData.
---@param dpiscale? number
--- DPI scale.
---@return LoveFontRasterizer
--- The rasterizer.
function love.font.newBMFontRasterizer(imageData, glyphs, dpiscale) end

--- Creates a new GlyphData.
---@param rasterizer LoveFontRasterizer
--- The Rasterizer containing the font.
---@param glyph number
--- The character code of the glyph.
function love.font.newGlyphData(rasterizer, glyph) end

--- Creates a new Image Rasterizer.
---@param imageData LoveImageImageData
--- Font image data.
---@param glyphs string
--- String containing font glyphs.
---@param extraSpacing? number
--- Font extra spacing.
---@param dpiscale? number
--- Font DPI scale.
---@return LoveFontRasterizer
--- The rasterizer.
function love.font.newImageRasterizer(imageData, glyphs, extraSpacing, dpiscale) end

--- Creates a new Rasterizer.
---@param fileName string
--- Path to font file.
---@param size? number
--- The font size.
---@param hinting? LoveFontHintingMode
--- True Type hinting mode.
---@param dpiscale? number
--- The font DPI scale.
---@overload fun(string)
---@overload fun(number?, LoveFontHintingMode?, number?)
---@return LoveFontRasterizer
--- The rasterizer.
function love.font.newRasterizer(fileName, size, hinting, dpiscale) end

--- Creates a new TrueType Rasterizer.
---@param fileName string
--- Path to font file.
---@param size? number
--- The font size.
---@param hinting? LoveFontHintingMode
--- True Type hinting mode.
---@param dpiscale? number
--- The font DPI scale.
---@overload fun(number?, LoveFontHintingMode?, number?)
---@return LoveFontRasterizer
--- The rasterizer.
function love.font.newTrueTypeRasterizer(fileName, size, hinting, dpiscale) end

--- ------------------------------------------------------------
--- love.graphics
--- The primary responsibility for the love.graphics module is the drawing of lines, shapes, text, Im...
---@class love.graphics
love.graphics = {}

--- Text alignment.
---@alias LoveGraphicsAlignMode
---| 'center' # Align text center.
---| 'left' # Align text left.
---| 'right' # Align text right.
---| 'justify' # Align text both left and right.

--- Different types of arcs that can be drawn.
---@alias LoveGraphicsArcType
---| 'pie' # The arc is drawn like a slice of pie, with the arc circle connected...
---| 'open' # The arc circle's two end-points are unconnected when the arc is dra...
---| 'closed' # The arc circle's two end-points are connected to each other.

--- Types of particle area spread distribution.
---@alias LoveGraphicsAreaSpreadDistribution
---| 'uniform' # Uniform distribution.
---| 'normal' # Normal (gaussian) distribution.
---| 'ellipse' # Uniform distribution in an ellipse.
---| 'borderellipse' # Distribution in an ellipse with particles spawning at the edges of ...
---| 'borderrectangle' # Distribution in a rectangle with particles spawning at the edges of...
---| 'none' # No distribution - area spread is disabled.

--- Different ways alpha affects color blending. See BlendMode and the BlendMode Formulas for additio...
---@alias LoveGraphicsBlendAlphaMode
---| 'alphamultiply' # The RGB values of what's drawn are multiplied by the alpha values o...
---| 'premultiplied' # The RGB values of what's drawn are '''not''' multiplied by the alph...

--- Different ways to do color blending. See BlendAlphaMode and the BlendMode Formulas for additional...
---@alias LoveGraphicsBlendMode
---| 'alpha' # Alpha blending (normal). The alpha of what's drawn determines its o...
---| 'replace' # The colors of what's drawn completely replace what was on the scree...
---| 'screen' # 'Screen' blending.
---| 'add' # The pixel colors of what's drawn are added to the pixel colors alre...
---| 'subtract' # The pixel colors of what's drawn are subtracted from the pixel colo...
---| 'multiply' # The pixel colors of what's drawn are multiplied with the pixel colo...
---| 'lighten' # The pixel colors of what's drawn are compared to the existing pixel...
---| 'darken' # The pixel colors of what's drawn are compared to the existing pixel...
---| 'additive' # Additive blend mode.
---| 'subtractive' # Subtractive blend mode.
---| 'multiplicative' # Multiply blend mode.
---| 'premultiplied' # Premultiplied alpha blend mode.

--- Different types of per-pixel stencil test and depth test comparisons. The pixels of an object wil...
---@alias LoveGraphicsCompareMode
---| 'equal' # * stencil tests: the stencil value of the pixel must be equal to th...
---| 'notequal' # * stencil tests: the stencil value of the pixel must not be equal t...
---| 'less' # * stencil tests: the stencil value of the pixel must be less than t...
---| 'lequal' # * stencil tests: the stencil value of the pixel must be less than o...
---| 'gequal' # * stencil tests: the stencil value of the pixel must be greater tha...
---| 'greater' # * stencil tests: the stencil value of the pixel must be greater tha...
---| 'never' # Objects will never be drawn.
---| 'always' # Objects will always be drawn. Effectively disables the depth or ste...

--- How Mesh geometry is culled when rendering.
---@alias LoveGraphicsCullMode
---| 'back' # Back-facing triangles in Meshes are culled (not rendered). The vert...
---| 'front' # Front-facing triangles in Meshes are culled.
---| 'none' # Both back- and front-facing triangles in Meshes are rendered.

--- Controls whether shapes are drawn as an outline, or filled.
---@alias LoveGraphicsDrawMode
---| 'fill' # Draw filled shape.
---| 'line' # Draw outlined shape.

--- How the image is filtered when scaling.
---@alias LoveGraphicsFilterMode
---| 'linear' # Scale image with linear interpolation.
---| 'nearest' # Scale image with nearest neighbor interpolation.

--- Graphics features that can be checked for with love.graphics.getSupported.
---@alias LoveGraphicsGraphicsFeature
---| 'clampzero' # Whether the "clampzero" WrapMode is supported.
---| 'lighten' # Whether the "lighten" and "darken" BlendModes are supported.
---| 'multicanvasformats' # Whether multiple formats can be used in the same love.graphics.setC...
---| 'glsl3' # Whether GLSL 3 Shaders can be used.
---| 'instancing' # Whether mesh instancing is supported.
---| 'fullnpot' # Whether textures with non-power-of-two dimensions can use mipmappin...
---| 'pixelshaderhighp' # Whether pixel shaders can use "highp" 32 bit floating point numbers...
---| 'shaderderivatives' # Whether shaders can use the dFdx, dFdy, and fwidth functions for co...

--- Types of system-dependent graphics limits checked for using love.graphics.getSystemLimits.
---@alias LoveGraphicsGraphicsLimit
---| 'pointsize' # The maximum size of points.
---| 'texturesize' # The maximum width or height of Images and Canvases.
---| 'multicanvas' # The maximum number of simultaneously active canvases (via love.grap...
---| 'canvasmsaa' # The maximum number of antialiasing samples for a Canvas.
---| 'texturelayers' # The maximum number of layers in an Array texture.
---| 'volumetexturesize' # The maximum width, height, or depth of a Volume texture.
---| 'cubetexturesize' # The maximum width or height of a Cubemap texture.
---| 'anisotropy' # The maximum amount of anisotropic filtering. Texture:setMipmapFilte...

--- Vertex map datatype for Data variant of Mesh:setVertexMap.
---@alias LoveGraphicsIndexDataType
---| 'uint16' # The vertex map is array of unsigned word (16-bit).
---| 'uint32' # The vertex map is array of unsigned dword (32-bit).

--- Line join style.
---@alias LoveGraphicsLineJoin
---| 'miter' # The ends of the line segments beveled in an angle so that they join...
---| 'none' # No cap applied to the ends of the line segments.
---| 'bevel' # Flattens the point where line segments join together.

--- The styles in which lines are drawn.
---@alias LoveGraphicsLineStyle
---| 'rough' # Draw rough lines.
---| 'smooth' # Draw smooth lines.

--- How a Mesh's vertices are used when drawing.
---@alias LoveGraphicsMeshDrawMode
---| 'fan' # The vertices create a "fan" shape with the first vertex acting as t...
---| 'strip' # The vertices create a series of connected triangles using vertices ...
---| 'triangles' # The vertices create unconnected triangles.
---| 'points' # The vertices are drawn as unconnected points (see love.graphics.set...

--- Controls whether a Canvas has mipmaps, and its behaviour when it does.
---@alias LoveGraphicsMipmapMode
---| 'none' # The Canvas has no mipmaps.
---| 'auto' # The Canvas has mipmaps. love.graphics.setCanvas can be used to rend...
---| 'manual' # The Canvas has mipmaps, and all mipmap levels will automatically be...

--- How newly created particles are added to the ParticleSystem.
---@alias LoveGraphicsParticleInsertMode
---| 'top' # Particles are inserted at the top of the ParticleSystem's list of p...
---| 'bottom' # Particles are inserted at the bottom of the ParticleSystem's list o...
---| 'random' # Particles are inserted at random positions in the ParticleSystem's ...

--- Usage hints for SpriteBatches and Meshes to optimize data storage and access.
---@alias LoveGraphicsSpriteBatchUsage
---| 'dynamic' # The object's data will change occasionally during its lifetime.
---| 'static' # The object will not be modified after initial sprites or vertices a...
---| 'stream' # The object data will always change between draws.

--- Graphics state stack types used with love.graphics.push.
---@alias LoveGraphicsStackType
---| 'transform' # The transformation stack (love.graphics.translate, love.graphics.ro...
---| 'all' # All love.graphics state, including transform state.

--- How a stencil function modifies the stencil values of pixels it touches.
---@alias LoveGraphicsStencilAction
---| 'replace' # The stencil value of a pixel will be replaced by the value specifie...
---| 'increment' # The stencil value of a pixel will be incremented by 1 for each obje...
---| 'decrement' # The stencil value of a pixel will be decremented by 1 for each obje...
---| 'incrementwrap' # The stencil value of a pixel will be incremented by 1 for each obje...
---| 'decrementwrap' # The stencil value of a pixel will be decremented by 1 for each obje...
---| 'invert' # The stencil value of a pixel will be bitwise-inverted for each obje...

--- Types of textures (2D, cubemap, etc.)
---@alias LoveGraphicsTextureType
---| '2d' # Regular 2D texture with width and height.
---| 'array' # Several same-size 2D textures organized into a single object. Simil...
---| 'cube' # Cubemap texture with 6 faces. Requires a custom shader (and Shader:...
---| 'volume' # 3D texture with width, height, and depth. Requires a custom shader ...

--- The frequency at which a vertex shader fetches the vertex attribute's data from the Mesh when it'...
---@alias LoveGraphicsVertexAttributeStep
---| 'pervertex' # The vertex attribute will have a unique value for each vertex in th...
---| 'perinstance' # The vertex attribute will have a unique value for each instance of ...

--- How Mesh geometry vertices are ordered.
---@alias LoveGraphicsVertexWinding
---| 'cw' # Clockwise.
---| 'ccw' # Counter-clockwise.

--- How the image wraps inside a Quad with a larger quad size than image size. This also affects how ...
---@alias LoveGraphicsWrapMode
---| 'clamp' # Clamp the texture. Appears only once. The area outside the texture'...
---| 'repeat' # Repeat the texture. Fills the whole available extent.
---| 'mirroredrepeat' # Repeat the texture, flipping it each time it repeats. May produce b...
---| 'clampzero' # Clamp the texture. Fills the area outside the texture's normal rang...

--- A Canvas is used for off-screen rendering. Think of it as an invisible screen that you can draw t...
---@class LoveGraphicsCanvas : LoveGraphicsTexture
--- (also inherits: Drawable, Object)
LoveGraphicsCanvas = {}

--- Generates mipmaps for the Canvas, based on the contents of the highest-resolution mipmap level. T...
function LoveGraphicsCanvas:generateMipmaps() end

--- Gets the number of multisample antialiasing (MSAA) samples used when drawing to the Canvas. This ...
---@return number
--- The number of multisample antialiasing samples used by the canvas when drawin...
function LoveGraphicsCanvas:getMSAA() end

--- Gets the MipmapMode this Canvas was created with.
---@return LoveGraphicsMipmapMode
--- The mipmap mode this Canvas was created with.
function LoveGraphicsCanvas:getMipmapMode() end

--- Generates ImageData from the contents of the Canvas.
---@param slice number
--- The cubemap face index, array index, or depth layer for cubemap, array, or vo...
---@param mipmap? number
--- The mipmap index to use, for Canvases with mipmaps.
---@param x number
--- The x-axis of the top-left corner (in pixels) of the area within the Canvas t...
---@param y number
--- The y-axis of the top-left corner (in pixels) of the area within the Canvas t...
---@param width number
--- The width in pixels of the area within the Canvas to capture.
---@param height number
--- The height in pixels of the area within the Canvas to capture.
---@overload fun()
---@return LoveImageImageData
--- The new ImageData made from the Canvas' contents.
function LoveGraphicsCanvas:newImageData(slice, mipmap, x, y, width, height) end

--- Render to the Canvas using a function. This is a shortcut to love.graphics.setCanvas: canvas:rend...
---@param func function
--- A function performing drawing operations.
---@param ___ any
--- Additional arguments to call the function with.
function LoveGraphicsCanvas:renderTo(func, ___) end

--- Superclass for all things that can be drawn on screen. This is an abstract type that can't be cre...
---@class LoveGraphicsDrawable
--- Defines the shape of characters that can be drawn onto the screen.
---@class LoveGraphicsFont
LoveGraphicsFont = {}

--- Gets the ascent of the Font. The ascent spans the distance between the baseline and the top of th...
---@return number
--- The ascent of the Font in pixels.
function LoveGraphicsFont:getAscent() end

--- Gets the baseline of the Font. Most scripts share the notion of a baseline: an imaginary horizont...
---@return number
--- The baseline of the Font in pixels.
function LoveGraphicsFont:getBaseline() end

--- Gets the DPI scale factor of the Font. The DPI scale factor represents relative pixel density. A ...
---@return number
--- The DPI scale factor of the Font.
function LoveGraphicsFont:getDPIScale() end

--- Gets the descent of the Font. The descent spans the distance between the baseline and the lowest ...
---@return number
--- The descent of the Font in pixels.
function LoveGraphicsFont:getDescent() end

--- Gets the filter mode for a font.
---@return LoveGraphicsFilterMode
--- Filter mode used when minifying the font.
---@return LoveGraphicsFilterMode
--- Filter mode used when magnifying the font.
---@return number
--- Maximum amount of anisotropic filtering used.
function LoveGraphicsFont:getFilter() end

--- Gets the height of the Font. The height of the font is the size including any spacing; the height...
---@return number
--- The height of the Font in pixels.
function LoveGraphicsFont:getHeight() end

--- Gets the kerning between two characters in the Font. Kerning is normally handled automatically in...
---@param leftchar string
--- The left character.
---@param rightchar string
--- The right character.
---@return number
--- The kerning amount to add to the spacing between the two characters. May be n...
function LoveGraphicsFont:getKerning(leftchar, rightchar) end

--- Gets the line height. This will be the value previously set by Font:setLineHeight, or 1.0 by defa...
---@return number
--- The current line height.
function LoveGraphicsFont:getLineHeight() end

--- Determines the maximum width (accounting for newlines) taken by the given string.
---@param text string
--- A string.
---@return number
--- The width of the text.
function LoveGraphicsFont:getWidth(text) end

--- Gets formatting information for text, given a wrap limit. This function accounts for newlines cor...
---@param text string
--- The text that will be wrapped.
---@param wraplimit number
--- The maximum width in pixels of each line that ''text'' is allowed before wrap...
---@return number
--- The maximum width of the wrapped text.
---@return table
--- A sequence containing each line of text that was wrapped.
function LoveGraphicsFont:getWrap(text, wraplimit) end

--- Gets whether the Font can render a character or string.
---@param character1 string
--- A unicode character.
---@param character2 string
--- Another unicode character.
---@overload fun(string)
---@return boolean
--- Whether the font can render all the glyphs represented by the characters.
function LoveGraphicsFont:hasGlyphs(character1, character2) end

--- Sets the fallback fonts. When the Font doesn't contain a glyph, it will substitute the glyph from...
---@param fallbackfont1 LoveGraphicsFont
--- The first fallback Font to use.
---@param ___ LoveGraphicsFont
--- Additional fallback Fonts.
function LoveGraphicsFont:setFallbacks(fallbackfont1, ___) end

--- Sets the filter mode for a font.
---@param min LoveGraphicsFilterMode
--- How to scale a font down.
---@param mag LoveGraphicsFilterMode
--- How to scale a font up.
---@param anisotropy? number
--- Maximum amount of anisotropic filtering used.
function LoveGraphicsFont:setFilter(min, mag, anisotropy) end

--- Sets the line height. When rendering the font in lines the actual height will be determined by th...
---@param height number
--- The new line height.
function LoveGraphicsFont:setLineHeight(height) end

--- Drawable image type.
---@class LoveGraphicsImage : LoveGraphicsTexture
--- (also inherits: Drawable, Object)
LoveGraphicsImage = {}

--- Gets whether the Image was created from CompressedData. Compressed images take up less space in V...
---@return boolean
--- Whether the Image is stored as a compressed texture on the GPU.
function LoveGraphicsImage:isCompressed() end

--- Gets whether the Image was created with the linear (non-gamma corrected) flag set to true. This m...
---@return boolean
--- Whether the Image's internal pixel format is linear (not gamma corrected), wh...
function LoveGraphicsImage:isFormatLinear() end

--- Replace the contents of an Image.
---@param data LoveImageImageData
--- The new ImageData to replace the contents with.
---@param slice? number
--- Which cubemap face, array index, or volume layer to replace, if applicable.
---@param mipmap? number
--- The mimap level to replace, if the Image has mipmaps.
---@param x? number
--- The x-offset in pixels from the top-left of the image to replace. The given I...
---@param y? number
--- The y-offset in pixels from the top-left of the image to replace. The given I...
---@param reloadmipmaps? boolean
--- Whether to generate new mipmaps after replacing the Image's pixels. True by d...
function LoveGraphicsImage:replacePixels(data, slice, mipmap, x, y, reloadmipmaps) end

--- A 2D polygon mesh used for drawing arbitrary textured shapes.
---@class LoveGraphicsMesh : LoveGraphicsDrawable
--- (also inherits: Object)
LoveGraphicsMesh = {}

--- Attaches a vertex attribute from a different Mesh onto this Mesh, for use when drawing. This can ...
---@param name string
--- The name of the vertex attribute to attach.
---@param mesh LoveGraphicsMesh
--- The Mesh to get the vertex attribute from.
---@param step? LoveGraphicsVertexAttributeStep
--- Whether the attribute will be per-vertex or per-instance when the mesh is drawn.
---@param attachname? string
--- The name of the attribute to use in shader code. Defaults to the name of the ...
---@overload fun(string, LoveGraphicsMesh)
function LoveGraphicsMesh:attachAttribute(name, mesh, step, attachname) end

--- Removes a previously attached vertex attribute from this Mesh.
---@param name string
--- The name of the attached vertex attribute to detach.
---@return boolean
--- Whether the attribute was successfully detached.
function LoveGraphicsMesh:detachAttribute(name) end

--- Immediately sends all modified vertex data in the Mesh to the graphics card. Normally it isn't ne...
function LoveGraphicsMesh:flush() end

--- Gets the mode used when drawing the Mesh.
---@return LoveGraphicsMeshDrawMode
--- The mode used when drawing the Mesh.
function LoveGraphicsMesh:getDrawMode() end

--- Gets the range of vertices used when drawing the Mesh.
---@return number
--- The index of the first vertex used when drawing, or the index of the first va...
---@return number
--- The index of the last vertex used when drawing, or the index of the last valu...
function LoveGraphicsMesh:getDrawRange() end

--- Gets the texture (Image or Canvas) used when drawing the Mesh.
---@return LoveGraphicsTexture
--- The Image or Canvas to texture the Mesh with when drawing, or nil if none is ...
function LoveGraphicsMesh:getTexture() end

--- Gets the properties of a vertex in the Mesh. In versions prior to 11.0, color and byte component ...
---@param index number
--- The one-based index of the vertex you want to retrieve the information for.
---@return number
--- The first component of the first vertex attribute in the specified vertex.
---@return number
--- Additional components of all vertex attributes in the specified vertex.
function LoveGraphicsMesh:getVertex(index) end

--- Gets the properties of a specific attribute within a vertex in the Mesh. Meshes without a custom ...
---@param vertexindex number
--- The index of the the vertex you want to retrieve the attribute for (one-based).
---@param attributeindex number
--- The index of the attribute within the vertex to be retrieved (one-based).
---@return number
--- The value of the first component of the attribute.
---@return number
--- The value of the second component of the attribute.
---@return number
--- Any additional vertex attribute components.
function LoveGraphicsMesh:getVertexAttribute(vertexindex, attributeindex) end

--- Gets the total number of vertices in the Mesh.
---@return number
--- The total number of vertices in the mesh.
function LoveGraphicsMesh:getVertexCount() end

--- Gets the vertex format that the Mesh was created with.
---@return table
--- The vertex format of the Mesh, which is a table containing tables for each ve...
function LoveGraphicsMesh:getVertexFormat() end

--- Gets the vertex map for the Mesh. The vertex map describes the order in which the vertices are us...
---@return table
--- A table containing the list of vertex indices used when drawing.
function LoveGraphicsMesh:getVertexMap() end

--- Gets whether a specific vertex attribute in the Mesh is enabled. Vertex data from disabled attrib...
---@param name string
--- The name of the vertex attribute to be checked.
---@return boolean
--- Whether the vertex attribute is used when drawing this Mesh.
function LoveGraphicsMesh:isAttributeEnabled(name) end

--- Enables or disables a specific vertex attribute in the Mesh. Vertex data from disabled attributes...
---@param name string
--- The name of the vertex attribute to enable or disable.
---@param enable boolean
--- Whether the vertex attribute is used when drawing this Mesh.
function LoveGraphicsMesh:setAttributeEnabled(name, enable) end

--- Sets the mode used when drawing the Mesh.
---@param mode LoveGraphicsMeshDrawMode
--- The mode to use when drawing the Mesh.
function LoveGraphicsMesh:setDrawMode(mode) end

--- Restricts the drawn vertices of the Mesh to a subset of the total.
---@param start number
--- The index of the first vertex to use when drawing, or the index of the first ...
---@param count number
--- The number of vertices to use when drawing, or number of values in the vertex...
---@overload fun()
function LoveGraphicsMesh:setDrawRange(start, count) end

--- Sets the texture (Image or Canvas) used when drawing the Mesh.
---@param texture LoveGraphicsTexture
--- The Image or Canvas to texture the Mesh with when drawing.
---@overload fun()
function LoveGraphicsMesh:setTexture(texture) end

--- Sets the properties of a vertex in the Mesh. In versions prior to 11.0, color and byte component ...
---@param index number
--- The index of the the vertex you want to modify (one-based).
---@param x number
--- The position of the vertex on the x-axis.
---@param y number
--- The position of the vertex on the y-axis.
---@param u number
--- The horizontal component of the texture coordinate.
---@param v number
--- The vertical component of the texture coordinate.
---@param r? number
--- The red component of the vertex's color.
---@param g? number
--- The green component of the vertex's color.
---@param b? number
--- The blue component of the vertex's color.
---@param a? number
--- The alpha component of the vertex's color.
---@overload fun(number, number, number)
---@overload fun(number, table)
function LoveGraphicsMesh:setVertex(index, x, y, u, v, r, g, b, a) end

--- Sets the properties of a specific attribute within a vertex in the Mesh. Meshes without a custom ...
---@param vertexindex number
--- The index of the the vertex to be modified (one-based).
---@param attributeindex number
--- The index of the attribute within the vertex to be modified (one-based).
---@param value1 number
--- The new value for the first component of the attribute.
---@param value2 number
--- The new value for the second component of the attribute.
---@param ___ number
--- Any additional vertex attribute components.
function LoveGraphicsMesh:setVertexAttribute(vertexindex, attributeindex, value1, value2, ___) end

--- Sets the vertex map for the Mesh. The vertex map describes the order in which the vertices are us...
---@param vi1 number
--- The index of the first vertex to use when drawing. Must be in the range of Me...
---@param vi2 number
--- The index of the second vertex to use when drawing.
---@param vi3 number
--- The index of the third vertex to use when drawing.
---@overload fun(table)
---@overload fun(any, LoveGraphicsIndexDataType)
function LoveGraphicsMesh:setVertexMap(vi1, vi2, vi3) end

--- Replaces a range of vertices in the Mesh with new ones. The total number of vertices in a Mesh ca...
---@param vertices table
--- The table filled with vertex information tables for each vertex, in the form ...
---@param startvertex? number
--- The index of the first vertex to replace.
---@param count? number
--- Amount of vertices to replace.
---@overload fun(any, number?)
---@overload fun(table)
function LoveGraphicsMesh:setVertices(vertices, startvertex, count) end

--- A ParticleSystem can be used to create particle effects like fire or smoke. The particle system h...
---@class LoveGraphicsParticleSystem : LoveGraphicsDrawable
--- (also inherits: Object)
LoveGraphicsParticleSystem = {}

--- Creates an identical copy of the ParticleSystem in the stopped state.
---@return LoveGraphicsParticleSystem
--- The new identical copy of this ParticleSystem.
function LoveGraphicsParticleSystem:clone() end

--- Emits a burst of particles from the particle emitter.
---@param numparticles number
--- The amount of particles to emit. The number of emitted particles will be trun...
function LoveGraphicsParticleSystem:emit(numparticles) end

--- Gets the maximum number of particles the ParticleSystem can have at once.
---@return number
--- The maximum number of particles.
function LoveGraphicsParticleSystem:getBufferSize() end

--- Gets the series of colors applied to the particle sprite. In versions prior to 11.0, color compon...
---@return number
--- First color, red component (0-1).
---@return number
--- First color, green component (0-1).
---@return number
--- First color, blue component (0-1).
---@return number
--- First color, alpha component (0-1).
---@return number
--- Second color, red component (0-1).
---@return number
--- Second color, green component (0-1).
---@return number
--- Second color, blue component (0-1).
---@return number
--- Second color, alpha component (0-1).
---@return number
--- Eighth color, red component (0-1).
---@return number
--- Eighth color, green component (0-1).
---@return number
--- Eighth color, blue component (0-1).
---@return number
--- Eighth color, alpha component (0-1).
function LoveGraphicsParticleSystem:getColors() end

--- Gets the number of particles that are currently in the system.
---@return number
--- The current number of live particles.
function LoveGraphicsParticleSystem:getCount() end

--- Gets the direction of the particle emitter (in radians).
---@return number
--- The direction of the emitter (radians).
function LoveGraphicsParticleSystem:getDirection() end

--- Gets the area-based spawn parameters for the particles.
---@return LoveGraphicsAreaSpreadDistribution
--- The type of distribution for new particles.
---@return number
--- The maximum spawn distance from the emitter along the x-axis for uniform dist...
---@return number
--- The maximum spawn distance from the emitter along the y-axis for uniform dist...
---@return number
--- The angle in radians of the emission area.
---@return boolean
--- True if newly spawned particles will be oriented relative to the center of th...
function LoveGraphicsParticleSystem:getEmissionArea() end

--- Gets the amount of particles emitted per second.
---@return number
--- The amount of particles per second.
function LoveGraphicsParticleSystem:getEmissionRate() end

--- Gets how long the particle system will emit particles (if -1 then it emits particles forever).
---@return number
--- The lifetime of the emitter (in seconds).
function LoveGraphicsParticleSystem:getEmitterLifetime() end

--- Gets the mode used when the ParticleSystem adds new particles.
---@return LoveGraphicsParticleInsertMode
--- The mode used when the ParticleSystem adds new particles.
function LoveGraphicsParticleSystem:getInsertMode() end

--- Gets the linear acceleration (acceleration along the x and y axes) for particles. Every particle ...
---@return number
--- The minimum acceleration along the x axis.
---@return number
--- The minimum acceleration along the y axis.
---@return number
--- The maximum acceleration along the x axis.
---@return number
--- The maximum acceleration along the y axis.
function LoveGraphicsParticleSystem:getLinearAcceleration() end

--- Gets the amount of linear damping (constant deceleration) for particles.
---@return number
--- The minimum amount of linear damping applied to particles.
---@return number
--- The maximum amount of linear damping applied to particles.
function LoveGraphicsParticleSystem:getLinearDamping() end

--- Gets the particle image's draw offset.
---@return number
--- The x coordinate of the particle image's draw offset.
---@return number
--- The y coordinate of the particle image's draw offset.
function LoveGraphicsParticleSystem:getOffset() end

--- Gets the lifetime of the particles.
---@return number
--- The minimum life of the particles (in seconds).
---@return number
--- The maximum life of the particles (in seconds).
function LoveGraphicsParticleSystem:getParticleLifetime() end

--- Gets the position of the emitter.
---@return number
--- Position along x-axis.
---@return number
--- Position along y-axis.
function LoveGraphicsParticleSystem:getPosition() end

--- Gets the series of Quads used for the particle sprites.
---@return table
--- A table containing the Quads used.
function LoveGraphicsParticleSystem:getQuads() end

--- Gets the radial acceleration (away from the emitter).
---@return number
--- The minimum acceleration.
---@return number
--- The maximum acceleration.
function LoveGraphicsParticleSystem:getRadialAcceleration() end

--- Gets the rotation of the image upon particle creation (in radians).
---@return number
--- The minimum initial angle (radians).
---@return number
--- The maximum initial angle (radians).
function LoveGraphicsParticleSystem:getRotation() end

--- Gets the amount of size variation (0 meaning no variation and 1 meaning full variation between st...
---@return number
--- The amount of variation (0 meaning no variation and 1 meaning full variation ...
function LoveGraphicsParticleSystem:getSizeVariation() end

--- Gets the series of sizes by which the sprite is scaled. 1.0 is normal size. The particle system w...
---@return number
--- The first size.
---@return number
--- The second size.
---@return number
--- The eighth size.
function LoveGraphicsParticleSystem:getSizes() end

--- Gets the speed of the particles.
---@return number
--- The minimum linear speed of the particles.
---@return number
--- The maximum linear speed of the particles.
function LoveGraphicsParticleSystem:getSpeed() end

--- Gets the spin of the sprite.
---@return number
--- The minimum spin (radians per second).
---@return number
--- The maximum spin (radians per second).
---@return number
--- The degree of variation (0 meaning no variation and 1 meaning full variation ...
function LoveGraphicsParticleSystem:getSpin() end

--- Gets the amount of spin variation (0 meaning no variation and 1 meaning full variation between st...
---@return number
--- The amount of variation (0 meaning no variation and 1 meaning full variation ...
function LoveGraphicsParticleSystem:getSpinVariation() end

--- Gets the amount of directional spread of the particle emitter (in radians).
---@return number
--- The spread of the emitter (radians).
function LoveGraphicsParticleSystem:getSpread() end

--- Gets the tangential acceleration (acceleration perpendicular to the particle's direction).
---@return number
--- The minimum acceleration.
---@return number
--- The maximum acceleration.
function LoveGraphicsParticleSystem:getTangentialAcceleration() end

--- Gets the texture (Image or Canvas) used for the particles.
---@return LoveGraphicsTexture
--- The Image or Canvas used for the particles.
function LoveGraphicsParticleSystem:getTexture() end

--- Gets whether particle angles and rotations are relative to their velocities. If enabled, particle...
---@return boolean
--- True if relative particle rotation is enabled, false if it's disabled.
function LoveGraphicsParticleSystem:hasRelativeRotation() end

--- Checks whether the particle system is actively emitting particles.
---@return boolean
--- True if system is active, false otherwise.
function LoveGraphicsParticleSystem:isActive() end

--- Checks whether the particle system is paused.
---@return boolean
--- True if system is paused, false otherwise.
function LoveGraphicsParticleSystem:isPaused() end

--- Checks whether the particle system is stopped.
---@return boolean
--- True if system is stopped, false otherwise.
function LoveGraphicsParticleSystem:isStopped() end

--- Moves the position of the emitter. This results in smoother particle spawning behaviour than if P...
---@param x number
--- Position along x-axis.
---@param y number
--- Position along y-axis.
function LoveGraphicsParticleSystem:moveTo(x, y) end

--- Pauses the particle emitter.
function LoveGraphicsParticleSystem:pause() end

--- Resets the particle emitter, removing any existing particles and resetting the lifetime counter.
function LoveGraphicsParticleSystem:reset() end

--- Sets the size of the buffer (the max allowed amount of particles in the system).
---@param size number
--- The buffer size.
function LoveGraphicsParticleSystem:setBufferSize(size) end

--- Sets a series of colors to apply to the particle sprite. The particle system will interpolate bet...
---@param r1 number
--- First color, red component (0-1).
---@param g1 number
--- First color, green component (0-1).
---@param b1 number
--- First color, blue component (0-1).
---@param a1? number
--- First color, alpha component (0-1).
---@param ___ number
--- Additional colors.
---@overload fun(table, table)
function LoveGraphicsParticleSystem:setColors(r1, g1, b1, a1, ___) end

--- Sets the direction the particles will be emitted in.
---@param direction number
--- The direction of the particles (in radians).
function LoveGraphicsParticleSystem:setDirection(direction) end

--- Sets area-based spawn parameters for the particles. Newly created particles will spawn in an area...
---@param distribution LoveGraphicsAreaSpreadDistribution
--- The type of distribution for new particles.
---@param dx number
--- The maximum spawn distance from the emitter along the x-axis for uniform dist...
---@param dy number
--- The maximum spawn distance from the emitter along the y-axis for uniform dist...
---@param angle? number
--- The angle in radians of the emission area.
---@param directionRelativeToCenter? boolean
--- True if newly spawned particles will be oriented relative to the center of th...
function LoveGraphicsParticleSystem:setEmissionArea(distribution, dx, dy, angle, directionRelativeToCenter) end

--- Sets the amount of particles emitted per second.
---@param rate number
--- The amount of particles per second.
function LoveGraphicsParticleSystem:setEmissionRate(rate) end

--- Sets how long the particle system should emit particles (if -1 then it emits particles forever).
---@param life number
--- The lifetime of the emitter (in seconds).
function LoveGraphicsParticleSystem:setEmitterLifetime(life) end

--- Sets the mode to use when the ParticleSystem adds new particles.
---@param mode LoveGraphicsParticleInsertMode
--- The mode to use when the ParticleSystem adds new particles.
function LoveGraphicsParticleSystem:setInsertMode(mode) end

--- Sets the linear acceleration (acceleration along the x and y axes) for particles. Every particle ...
---@param xmin number
--- The minimum acceleration along the x axis.
---@param ymin number
--- The minimum acceleration along the y axis.
---@param xmax? number
--- The maximum acceleration along the x axis.
---@param ymax? number
--- The maximum acceleration along the y axis.
function LoveGraphicsParticleSystem:setLinearAcceleration(xmin, ymin, xmax, ymax) end

--- Sets the amount of linear damping (constant deceleration) for particles.
---@param min number
--- The minimum amount of linear damping applied to particles.
---@param max? number
--- The maximum amount of linear damping applied to particles.
function LoveGraphicsParticleSystem:setLinearDamping(min, max) end

--- Set the offset position which the particle sprite is rotated around. If this function is not used...
---@param x number
--- The x coordinate of the rotation offset.
---@param y number
--- The y coordinate of the rotation offset.
function LoveGraphicsParticleSystem:setOffset(x, y) end

--- Sets the lifetime of the particles.
---@param min number
--- The minimum life of the particles (in seconds).
---@param max? number
--- The maximum life of the particles (in seconds).
function LoveGraphicsParticleSystem:setParticleLifetime(min, max) end

--- Sets the position of the emitter.
---@param x number
--- Position along x-axis.
---@param y number
--- Position along y-axis.
function LoveGraphicsParticleSystem:setPosition(x, y) end

--- Sets a series of Quads to use for the particle sprites. Particles will choose a Quad from the lis...
---@param quad1 LoveGraphicsQuad
--- The first Quad to use.
---@param ___ LoveGraphicsQuad
--- Additional Quads to use.
---@overload fun(table)
function LoveGraphicsParticleSystem:setQuads(quad1, ___) end

--- Set the radial acceleration (away from the emitter).
---@param min number
--- The minimum acceleration.
---@param max? number
--- The maximum acceleration.
function LoveGraphicsParticleSystem:setRadialAcceleration(min, max) end

--- Sets whether particle angles and rotations are relative to their velocities. If enabled, particle...
---@param enable boolean
--- True to enable relative particle rotation, false to disable it.
function LoveGraphicsParticleSystem:setRelativeRotation(enable) end

--- Sets the rotation of the image upon particle creation (in radians).
---@param min number
--- The minimum initial angle (radians).
---@param max? number
--- The maximum initial angle (radians).
function LoveGraphicsParticleSystem:setRotation(min, max) end

--- Sets the amount of size variation (0 meaning no variation and 1 meaning full variation between st...
---@param variation number
--- The amount of variation (0 meaning no variation and 1 meaning full variation ...
function LoveGraphicsParticleSystem:setSizeVariation(variation) end

--- Sets a series of sizes by which to scale a particle sprite. 1.0 is normal size. The particle syst...
---@param size1 number
--- The first size.
---@param size2? number
--- The second size.
---@param size8? number
--- The eighth size.
function LoveGraphicsParticleSystem:setSizes(size1, size2, size8) end

--- Sets the speed of the particles.
---@param min number
--- The minimum linear speed of the particles.
---@param max? number
--- The maximum linear speed of the particles.
function LoveGraphicsParticleSystem:setSpeed(min, max) end

--- Sets the spin of the sprite.
---@param min number
--- The minimum spin (radians per second).
---@param max? number
--- The maximum spin (radians per second).
function LoveGraphicsParticleSystem:setSpin(min, max) end

--- Sets the amount of spin variation (0 meaning no variation and 1 meaning full variation between st...
---@param variation number
--- The amount of variation (0 meaning no variation and 1 meaning full variation ...
function LoveGraphicsParticleSystem:setSpinVariation(variation) end

--- Sets the amount of spread for the system.
---@param spread number
--- The amount of spread (radians).
function LoveGraphicsParticleSystem:setSpread(spread) end

--- Sets the tangential acceleration (acceleration perpendicular to the particle's direction).
---@param min number
--- The minimum acceleration.
---@param max? number
--- The maximum acceleration.
function LoveGraphicsParticleSystem:setTangentialAcceleration(min, max) end

--- Sets the texture (Image or Canvas) to be used for the particles.
---@param texture LoveGraphicsTexture
--- An Image or Canvas to use for the particles.
function LoveGraphicsParticleSystem:setTexture(texture) end

--- Starts the particle emitter.
function LoveGraphicsParticleSystem:start() end

--- Stops the particle emitter, resetting the lifetime counter.
function LoveGraphicsParticleSystem:stop() end

--- Updates the particle system; moving, creating and killing particles.
---@param dt number
--- The time (seconds) since last frame.
function LoveGraphicsParticleSystem:update(dt) end

--- A quadrilateral (a polygon with four sides and four corners) with texture coordinate information....
---@class LoveGraphicsQuad
LoveGraphicsQuad = {}

--- Gets reference texture dimensions initially specified in love.graphics.newQuad.
---@return number
--- The Texture width used by the Quad.
---@return number
--- The Texture height used by the Quad.
function LoveGraphicsQuad:getTextureDimensions() end

--- Gets the current viewport of this Quad.
---@return number
--- The top-left corner along the x-axis.
---@return number
--- The top-left corner along the y-axis.
---@return number
--- The width of the viewport.
---@return number
--- The height of the viewport.
function LoveGraphicsQuad:getViewport() end

--- Sets the texture coordinates according to a viewport.
---@param x number
--- The top-left corner along the x-axis.
---@param y number
--- The top-left corner along the y-axis.
---@param w number
--- The width of the viewport.
---@param h number
--- The height of the viewport.
---@param sw? number
--- Optional new reference width, the width of the Texture. Must be greater than ...
---@param sh? number
--- Optional new reference height, the height of the Texture. Must be greater tha...
function LoveGraphicsQuad:setViewport(x, y, w, h, sw, sh) end

--- A Shader is used for advanced hardware-accelerated pixel or vertex manipulation. These effects ar...
---@class LoveGraphicsShader
LoveGraphicsShader = {}

--- Returns any warning and error messages from compiling the shader code. This can be used for debug...
---@return string
--- Warning and error messages (if any).
function LoveGraphicsShader:getWarnings() end

--- Gets whether a uniform / extern variable exists in the Shader. If a graphics driver's shader comp...
---@param name string
--- The name of the uniform variable.
---@return boolean
--- Whether the uniform exists in the shader and affects its final output.
function LoveGraphicsShader:hasUniform(name) end

--- Sends one or more values to a special (''uniform'') variable inside the shader. Uniform variables...
---@param name string
--- Name of the uniform matrix to send to the shader.
---@param data any
--- [Data] Data object containing the values to send.
---@param matrixlayout LoveMathMatrixLayout
--- The layout (row- or column-major) of the matrix in memory.
---@param offset? number
--- Offset in bytes from the start of the Data object.
---@param size? number
--- Size in bytes of the data to send. If nil, as many bytes as the specified uni...
---@overload fun(string, number, number)
---@overload fun(string, LoveGraphicsTexture)
---@overload fun(string, LoveMathMatrixLayout, table, table)
function LoveGraphicsShader:send(name, data, matrixlayout, offset, size) end

--- Sends one or more colors to a special (''extern'' / ''uniform'') vec3 or vec4 variable inside the...
---@param name string
--- The name of the color extern variable to send to in the shader.
---@param color table
--- A table with red, green, blue, and optional alpha color components in the ran...
---@param ___ table
--- Additional colors to send in case the extern is an array. All colors need to ...
function LoveGraphicsShader:sendColor(name, color, ___) end

--- Using a single image, draw any number of identical copies of the image using a single call to lov...
---@class LoveGraphicsSpriteBatch : LoveGraphicsDrawable
--- (also inherits: Object)
LoveGraphicsSpriteBatch = {}

--- Adds a sprite to the batch. Sprites are drawn in the order they are added.
---@param quad LoveGraphicsQuad
--- The Quad to add.
---@param x number
--- The position to draw the object (x-axis).
---@param y number
--- The position to draw the object (y-axis).
---@param r? number
--- Orientation (radians).
---@param sx? number
--- Scale factor (x-axis).
---@param sy? number
--- Scale factor (y-axis).
---@param ox? number
--- Origin offset (x-axis).
---@param oy? number
--- Origin offset (y-axis).
---@param kx? number
--- Shear factor (x-axis).
---@param ky? number
--- Shear factor (y-axis).
---@overload fun(number, number, number?, number?, number?, number?, number?, number?, number?)
---@return number
--- An identifier for the added sprite.
function LoveGraphicsSpriteBatch:add(quad, x, y, r, sx, sy, ox, oy, kx, ky) end

--- Adds a sprite to a batch created with an Array Texture.
---@param layerindex number
--- The index of the layer to use for this sprite.
---@param quad LoveGraphicsQuad
--- The subsection of the texture's layer to use when drawing the sprite.
---@param x? number
--- The position to draw the sprite (x-axis).
---@param y? number
--- The position to draw the sprite (y-axis).
---@param r? number
--- Orientation (radians).
---@param sx? number
--- Scale factor (x-axis).
---@param sy? number
--- Scale factor (y-axis).
---@param ox? number
--- Origin offset (x-axis).
---@param oy? number
--- Origin offset (y-axis).
---@param kx? number
--- Shearing factor (x-axis).
---@param ky? number
--- Shearing factor (y-axis).
---@overload fun(number, number?, number?, number?, number?, number?, number?, number?, number?, number?)
---@overload fun(number, LoveMathTransform)
---@overload fun(number, LoveGraphicsQuad, LoveMathTransform)
---@return number
--- The index of the added sprite, for use with SpriteBatch:set or SpriteBatch:se...
function LoveGraphicsSpriteBatch:addLayer(layerindex, quad, x, y, r, sx, sy, ox, oy, kx, ky) end

--- Attaches a per-vertex attribute from a Mesh onto this SpriteBatch, for use when drawing. This can...
---@param name string
--- The name of the vertex attribute to attach.
---@param mesh LoveGraphicsMesh
--- The Mesh to get the vertex attribute from.
function LoveGraphicsSpriteBatch:attachAttribute(name, mesh) end

--- Removes all sprites from the buffer.
function LoveGraphicsSpriteBatch:clear() end

--- Immediately sends all new and modified sprite data in the batch to the graphics card. Normally it...
function LoveGraphicsSpriteBatch:flush() end

--- Gets the maximum number of sprites the SpriteBatch can hold.
---@return number
--- The maximum number of sprites the batch can hold.
function LoveGraphicsSpriteBatch:getBufferSize() end

--- Gets the color that will be used for the next add and set operations. If no color has been set wi...
---@return number
--- The red component (0-1).
---@return number
--- The green component (0-1).
---@return number
--- The blue component (0-1).
---@return number
--- The alpha component (0-1).
function LoveGraphicsSpriteBatch:getColor() end

--- Gets the number of sprites currently in the SpriteBatch.
---@return number
--- The number of sprites currently in the batch.
function LoveGraphicsSpriteBatch:getCount() end

--- Gets the texture (Image or Canvas) used by the SpriteBatch.
---@return LoveGraphicsTexture
--- The Image or Canvas used by the SpriteBatch.
function LoveGraphicsSpriteBatch:getTexture() end

--- Changes a sprite in the batch. This requires the sprite index returned by SpriteBatch:add or Spri...
---@param spriteindex number
--- The index of the sprite that will be changed.
---@param quad LoveGraphicsQuad
--- The Quad used on the image of the batch.
---@param x number
--- The position to draw the object (x-axis).
---@param y number
--- The position to draw the object (y-axis).
---@param r? number
--- Orientation (radians).
---@param sx? number
--- Scale factor (x-axis).
---@param sy? number
--- Scale factor (y-axis).
---@param ox? number
--- Origin offset (x-axis).
---@param oy? number
--- Origin offset (y-axis).
---@param kx? number
--- Shear factor (x-axis).
---@param ky? number
--- Shear factor (y-axis).
---@overload fun(number, number, number, number?, number?, number?, number?, number?, number?, number?)
function LoveGraphicsSpriteBatch:set(spriteindex, quad, x, y, r, sx, sy, ox, oy, kx, ky) end

--- Sets the color that will be used for the next add and set operations. Calling the function withou...
---@param r number
--- The amount of red.
---@param g number
--- The amount of green.
---@param b number
--- The amount of blue.
---@param a? number
--- The amount of alpha.
---@overload fun()
function LoveGraphicsSpriteBatch:setColor(r, g, b, a) end

--- Restricts the drawn sprites in the SpriteBatch to a subset of the total.
---@param start number
--- The index of the first sprite to draw. Index 1 corresponds to the first sprit...
---@param count number
--- The number of sprites to draw.
---@overload fun()
function LoveGraphicsSpriteBatch:setDrawRange(start, count) end

--- Changes a sprite previously added with add or addLayer, in a batch created with an Array Texture.
---@param spriteindex number
--- The index of the existing sprite to replace.
---@param layerindex number
--- The index of the layer to use for this sprite.
---@param quad LoveGraphicsQuad
--- The subsection of the texture's layer to use when drawing the sprite.
---@param x? number
--- The position to draw the sprite (x-axis).
---@param y? number
--- The position to draw the sprite (y-axis).
---@param r? number
--- Orientation (radians).
---@param sx? number
--- Scale factor (x-axis).
---@param sy? number
--- Scale factor (y-axis).
---@param ox? number
--- Origin offset (x-axis).
---@param oy? number
--- Origin offset (y-axis).
---@param kx? number
--- Shearing factor (x-axis).
---@param ky? number
--- Shearing factor (y-axis).
---@overload fun(number, number, number?, number?, number?, number?, number?, number?, number?, number?,...)
---@overload fun(number, number, LoveMathTransform)
---@overload fun(number, number, LoveGraphicsQuad, LoveMathTransform)
function LoveGraphicsSpriteBatch:setLayer(spriteindex, layerindex, quad, x, y, r, sx, sy, ox, oy, kx, ky) end

--- Sets the texture (Image or Canvas) used for the sprites in the batch, when drawing.
---@param texture LoveGraphicsTexture
--- The new Image or Canvas to use for the sprites in the batch.
function LoveGraphicsSpriteBatch:setTexture(texture) end

--- Drawable text.
---@class LoveGraphicsText : LoveGraphicsDrawable
--- (also inherits: Object)
LoveGraphicsText = {}

--- Adds additional colored text to the Text object at the specified position.
---@param textstring string
--- The text to add to the object.
---@param x? number
--- The position of the new text on the x-axis.
---@param y? number
--- The position of the new text on the y-axis.
---@param angle? number
--- The orientation of the new text in radians.
---@param sx? number
--- Scale factor on the x-axis.
---@param sy? number
--- Scale factor on the y-axis.
---@param ox? number
--- Origin offset on the x-axis.
---@param oy? number
--- Origin offset on the y-axis.
---@param kx? number
--- Shearing / skew factor on the x-axis.
---@param ky? number
--- Shearing / skew factor on the y-axis.
---@return number
--- An index number that can be used with Text:getWidth or Text:getHeight.
function LoveGraphicsText:add(textstring, x, y, angle, sx, sy, ox, oy, kx, ky) end

--- Adds additional formatted / colored text to the Text object at the specified position. The word w...
---@param textstring string
--- The text to add to the object.
---@param wraplimit number
--- The maximum width in pixels of the text before it gets automatically wrapped ...
---@param align LoveGraphicsAlignMode
--- The alignment of the text.
---@param x number
--- The position of the new text (x-axis).
---@param y number
--- The position of the new text (y-axis).
---@param angle? number
--- Orientation (radians).
---@param sx? number
--- Scale factor (x-axis).
---@param sy? number
--- Scale factor (y-axis).
---@param ox? number
--- Origin offset (x-axis).
---@param oy? number
--- Origin offset (y-axis).
---@param kx? number
--- Shearing / skew factor (x-axis).
---@param ky? number
--- Shearing / skew factor (y-axis).
---@return number
--- An index number that can be used with Text:getWidth or Text:getHeight.
function LoveGraphicsText:addf(textstring, wraplimit, align, x, y, angle, sx, sy, ox, oy, kx, ky) end

--- Clears the contents of the Text object.
function LoveGraphicsText:clear() end

--- Gets the width and height of the text in pixels.
---@param index number
--- An index number returned by Text:add or Text:addf.
---@overload fun()
---@return number
--- The width of the sub-string (before scaling and other transformations).
---@return number
--- The height of the sub-string (before scaling and other transformations).
function LoveGraphicsText:getDimensions(index) end

--- Gets the Font used with the Text object.
---@return LoveGraphicsFont
--- The font used with this Text object.
function LoveGraphicsText:getFont() end

--- Gets the height of the text in pixels.
---@param index number
--- An index number returned by Text:add or Text:addf.
---@overload fun()
---@return number
--- The height of the sub-string (before scaling and other transformations).
function LoveGraphicsText:getHeight(index) end

--- Gets the width of the text in pixels.
---@param index number
--- An index number returned by Text:add or Text:addf.
---@overload fun()
---@return number
--- The width of the sub-string (before scaling and other transformations).
function LoveGraphicsText:getWidth(index) end

--- Replaces the contents of the Text object with a new unformatted string.
---@param textstring string
--- The new string of text to use.
function LoveGraphicsText:set(textstring) end

--- Replaces the Font used with the text.
---@param font LoveGraphicsFont
--- The new font to use with this Text object.
function LoveGraphicsText:setFont(font) end

--- Replaces the contents of the Text object with a new formatted string.
---@param textstring string
--- The new string of text to use.
---@param wraplimit number
--- The maximum width in pixels of the text before it gets automatically wrapped ...
---@param align LoveGraphicsAlignMode
--- The alignment of the text.
function LoveGraphicsText:setf(textstring, wraplimit, align) end

--- Superclass for drawable objects which represent a texture. All Textures can be drawn with Quads. ...
---@class LoveGraphicsTexture : LoveGraphicsDrawable
--- (also inherits: Object)
LoveGraphicsTexture = {}

--- Gets the DPI scale factor of the Texture. The DPI scale factor represents relative pixel density....
---@return number
--- The DPI scale factor of the Texture.
function LoveGraphicsTexture:getDPIScale() end

--- Gets the depth of a Volume Texture. Returns 1 for 2D, Cubemap, and Array textures.
---@return number
--- The depth of the volume Texture.
function LoveGraphicsTexture:getDepth() end

--- Gets the comparison mode used when sampling from a depth texture in a shader. Depth texture compa...
---@return LoveGraphicsCompareMode
--- The comparison mode used when sampling from this texture in a shader, or nil ...
function LoveGraphicsTexture:getDepthSampleMode() end

--- Gets the width and height of the Texture.
---@return number
--- The width of the Texture.
---@return number
--- The height of the Texture.
function LoveGraphicsTexture:getDimensions() end

--- Gets the filter mode of the Texture.
---@return LoveGraphicsFilterMode
--- Filter mode to use when minifying the texture (rendering it at a smaller size...
---@return LoveGraphicsFilterMode
--- Filter mode to use when magnifying the texture (rendering it at a smaller siz...
---@return number
--- Maximum amount of anisotropic filtering used.
function LoveGraphicsTexture:getFilter() end

--- Gets the pixel format of the Texture.
---@return LoveImagePixelFormat
--- The pixel format the Texture was created with.
function LoveGraphicsTexture:getFormat() end

--- Gets the height of the Texture.
---@return number
--- The height of the Texture.
function LoveGraphicsTexture:getHeight() end

--- Gets the number of layers / slices in an Array Texture. Returns 1 for 2D, Cubemap, and Volume tex...
---@return number
--- The number of layers in the Array Texture.
function LoveGraphicsTexture:getLayerCount() end

--- Gets the number of mipmaps contained in the Texture. If the texture was not created with mipmaps,...
---@return number
--- The number of mipmaps in the Texture.
function LoveGraphicsTexture:getMipmapCount() end

--- Gets the mipmap filter mode for a Texture. Prior to 11.0 this method only worked on Images.
---@return LoveGraphicsFilterMode
--- The filter mode used in between mipmap levels. nil if mipmap filtering is not...
---@return number
--- Value used to determine whether the image should use more or less detailed mi...
function LoveGraphicsTexture:getMipmapFilter() end

--- Gets the width and height in pixels of the Texture. Texture:getDimensions gets the dimensions of ...
---@return number
--- The width of the Texture, in pixels.
---@return number
--- The height of the Texture, in pixels.
function LoveGraphicsTexture:getPixelDimensions() end

--- Gets the height in pixels of the Texture. DPI scale factor, rather than pixels. Use getHeight for...
---@return number
--- The height of the Texture, in pixels.
function LoveGraphicsTexture:getPixelHeight() end

--- Gets the width in pixels of the Texture. DPI scale factor, rather than pixels. Use getWidth for c...
---@return number
--- The width of the Texture, in pixels.
function LoveGraphicsTexture:getPixelWidth() end

--- Gets the type of the Texture.
---@return LoveGraphicsTextureType
--- The type of the Texture.
function LoveGraphicsTexture:getTextureType() end

--- Gets the width of the Texture.
---@return number
--- The width of the Texture.
function LoveGraphicsTexture:getWidth() end

--- Gets the wrapping properties of a Texture. This function returns the currently set horizontal and...
---@return LoveGraphicsWrapMode
--- Horizontal wrapping mode of the texture.
---@return LoveGraphicsWrapMode
--- Vertical wrapping mode of the texture.
---@return LoveGraphicsWrapMode
--- Wrapping mode for the z-axis of a Volume texture.
function LoveGraphicsTexture:getWrap() end

--- Gets whether the Texture can be drawn and sent to a Shader. Canvases created with stencil and/or ...
---@return boolean
--- Whether the Texture is readable.
function LoveGraphicsTexture:isReadable() end

--- Sets the comparison mode used when sampling from a depth texture in a shader. Depth texture compa...
---@param compare LoveGraphicsCompareMode
--- The comparison mode used when sampling from this texture in a shader.
function LoveGraphicsTexture:setDepthSampleMode(compare) end

--- Sets the filter mode of the Texture.
---@param min LoveGraphicsFilterMode
--- Filter mode to use when minifying the texture (rendering it at a smaller size...
---@param mag? LoveGraphicsFilterMode
--- Filter mode to use when magnifying the texture (rendering it at a larger size...
---@param anisotropy? number
--- Maximum amount of anisotropic filtering to use.
function LoveGraphicsTexture:setFilter(min, mag, anisotropy) end

--- Sets the mipmap filter mode for a Texture. Prior to 11.0 this method only worked on Images. Mipma...
---@param filtermode LoveGraphicsFilterMode
--- The filter mode to use in between mipmap levels. 'nearest' will often give be...
---@param sharpness? number
--- A positive sharpness value makes the texture use a more detailed mipmap level...
---@overload fun()
function LoveGraphicsTexture:setMipmapFilter(filtermode, sharpness) end

--- Sets the wrapping properties of a Texture. This function sets the way a Texture is repeated when ...
---@param horiz LoveGraphicsWrapMode
--- Horizontal wrapping mode of the texture.
---@param vert? LoveGraphicsWrapMode
--- Vertical wrapping mode of the texture.
---@param depth? LoveGraphicsWrapMode
--- Wrapping mode for the z-axis of a Volume texture.
function LoveGraphicsTexture:setWrap(horiz, vert, depth) end

--- A drawable video.
---@class LoveGraphicsVideo : LoveGraphicsDrawable
--- (also inherits: Object)
LoveGraphicsVideo = {}

--- Gets the width and height of the Video in pixels.
---@return number
--- The width of the Video.
---@return number
--- The height of the Video.
function LoveGraphicsVideo:getDimensions() end

--- Gets the scaling filters used when drawing the Video.
---@return LoveGraphicsFilterMode
--- The filter mode used when scaling the Video down.
---@return LoveGraphicsFilterMode
--- The filter mode used when scaling the Video up.
---@return number
--- Maximum amount of anisotropic filtering used.
function LoveGraphicsVideo:getFilter() end

--- Gets the height of the Video in pixels.
---@return number
--- The height of the Video.
function LoveGraphicsVideo:getHeight() end

--- Gets the audio Source used for playing back the video's audio. May return nil if the video has no...
---@return LoveAudioSource
--- The audio Source used for audio playback, or nil if the video has no audio.
function LoveGraphicsVideo:getSource() end

--- Gets the VideoStream object used for decoding and controlling the video.
---@return LoveVideoVideoStream
--- The VideoStream used for decoding and controlling the video.
function LoveGraphicsVideo:getStream() end

--- Gets the width of the Video in pixels.
---@return number
--- The width of the Video.
function LoveGraphicsVideo:getWidth() end

--- Gets whether the Video is currently playing.
---@return boolean
--- Whether the video is playing.
function LoveGraphicsVideo:isPlaying() end

--- Pauses the Video.
function LoveGraphicsVideo:pause() end

--- Starts playing the Video. In order for the video to appear onscreen it must be drawn with love.gr...
function LoveGraphicsVideo:play() end

--- Rewinds the Video to the beginning.
function LoveGraphicsVideo:rewind() end

--- Sets the current playback position of the Video.
---@param offset number
--- The time in seconds since the beginning of the Video.
function LoveGraphicsVideo:seek(offset) end

--- Sets the scaling filters used when drawing the Video.
---@param min LoveGraphicsFilterMode
--- The filter mode used when scaling the Video down.
---@param mag LoveGraphicsFilterMode
--- The filter mode used when scaling the Video up.
---@param anisotropy? number
--- Maximum amount of anisotropic filtering used.
function LoveGraphicsVideo:setFilter(min, mag, anisotropy) end

--- Sets the audio Source used for playing back the video's audio. The audio Source also controls pla...
---@param source? LoveAudioSource
--- The audio Source used for audio playback, or nil to disable audio synchroniza...
function LoveGraphicsVideo:setSource(source) end

--- Gets the current playback position of the Video.
---@return number
--- The time in seconds since the beginning of the Video.
function LoveGraphicsVideo:tell() end

--- Applies the given Transform object to the current coordinate transformation. This effectively mul...
---@param transform LoveMathTransform
--- The Transform object to apply to the current graphics coordinate transform.
function love.graphics.applyTransform(transform) end

--- Draws a filled or unfilled arc at position (x, y). The arc is drawn from angle1 to angle2 in radi...
---@param drawmode LoveGraphicsDrawMode
--- How to draw the arc.
---@param arctype LoveGraphicsArcType
--- The type of arc to draw.
---@param x number
--- The position of the center along x-axis.
---@param y number
--- The position of the center along y-axis.
---@param radius number
--- Radius of the arc.
---@param angle1 number
--- The angle at which the arc begins.
---@param angle2 number
--- The angle at which the arc terminates.
---@param segments? number
--- The number of segments used for drawing the arc.
---@overload fun(LoveGraphicsDrawMode, number, number, number, number, number, number?)
function love.graphics.arc(drawmode, arctype, x, y, radius, angle1, angle2, segments) end

--- Creates a screenshot once the current frame is done (after love.draw has finished). Since this fu...
---@param filename string
--- The filename to save the screenshot to. The encoded image type is determined ...
function love.graphics.captureScreenshot(filename) end

--- Draws a circle.
---@param mode LoveGraphicsDrawMode
--- How to draw the circle.
---@param x number
--- The position of the center along x-axis.
---@param y number
--- The position of the center along y-axis.
---@param radius number
--- The radius of the circle.
---@param segments number
--- The number of segments used for drawing the circle. Note: The default variabl...
---@overload fun(LoveGraphicsDrawMode, number, number, number)
function love.graphics.circle(mode, x, y, radius, segments) end

--- Clears the screen or active Canvas to the specified color. This function is called automatically ...
---@param r number
--- The red channel of the color to clear the screen to.
---@param g number
--- The green channel of the color to clear the screen to.
---@param b number
--- The blue channel of the color to clear the screen to.
---@param a? number
--- The alpha channel of the color to clear the screen to.
---@param clearstencil? boolean
--- Whether to clear the active stencil buffer, if present. It can also be an int...
---@param cleardepth? boolean
--- Whether to clear the active depth buffer, if present. It can also be a number...
---@overload fun()
---@overload fun(table, table, boolean?, boolean?)
---@overload fun(boolean, boolean, boolean)
function love.graphics.clear(r, g, b, a, clearstencil, cleardepth) end

--- Discards (trashes) the contents of the screen or active Canvas. This is a performance optimizatio...
---@param discardcolor? boolean
--- Whether to discard the texture(s) of the active Canvas(es) (the contents of t...
---@param discardstencil? boolean
--- Whether to discard the contents of the stencil buffer of the screen / active ...
function love.graphics.discard(discardcolor, discardstencil) end

--- Draws a Drawable object (an Image, Canvas, SpriteBatch, ParticleSystem, Mesh, Text object, or Vid...
---@param texture LoveGraphicsTexture
--- A Texture (Image or Canvas) to texture the Quad with.
---@param quad LoveGraphicsQuad
--- The Quad to draw on screen.
---@param x number
--- The position to draw the object (x-axis).
---@param y number
--- The position to draw the object (y-axis).
---@param r? number
--- Orientation (radians).
---@param sx? number
--- Scale factor (x-axis).
---@param sy? number
--- Scale factor (y-axis).
---@param ox? number
--- Origin offset (x-axis).
---@param oy? number
--- Origin offset (y-axis).
---@param kx? number
--- Shearing factor (x-axis).
---@param ky? number
--- Shearing factor (y-axis).
---@overload fun(LoveGraphicsDrawable, number?, number?, number?, number?, number?, number?, number?, nu...)
---@overload fun(LoveGraphicsDrawable, LoveMathTransform)
---@overload fun(LoveGraphicsTexture, LoveGraphicsQuad, LoveMathTransform)
function love.graphics.draw(texture, quad, x, y, r, sx, sy, ox, oy, kx, ky) end

--- Draws many instances of a Mesh with a single draw call, using hardware geometry instancing. Each ...
---@param mesh LoveGraphicsMesh
--- The mesh to render.
---@param instancecount number
--- The number of instances to render.
---@param x? number
--- The position to draw the instances (x-axis).
---@param y? number
--- The position to draw the instances (y-axis).
---@param r? number
--- Orientation (radians).
---@param sx? number
--- Scale factor (x-axis).
---@param sy? number
--- Scale factor (y-axis).
---@param ox? number
--- Origin offset (x-axis).
---@param oy? number
--- Origin offset (y-axis).
---@param kx? number
--- Shearing factor (x-axis).
---@param ky? number
--- Shearing factor (y-axis).
---@overload fun(LoveGraphicsMesh, number, LoveMathTransform)
function love.graphics.drawInstanced(mesh, instancecount, x, y, r, sx, sy, ox, oy, kx, ky) end

--- Draws a layer of an Array Texture.
---@param texture LoveGraphicsTexture
--- The Array Texture to draw.
---@param layerindex number
--- The index of the layer to use when drawing.
---@param quad LoveGraphicsQuad
--- The subsection of the texture's layer to use when drawing.
---@param x? number
--- The position to draw the texture (x-axis).
---@param y? number
--- The position to draw the texture (y-axis).
---@param r? number
--- Orientation (radians).
---@param sx? number
--- Scale factor (x-axis).
---@param sy? number
--- Scale factor (y-axis).
---@param ox? number
--- Origin offset (x-axis).
---@param oy? number
--- Origin offset (y-axis).
---@param kx? number
--- Shearing factor (x-axis).
---@param ky? number
--- Shearing factor (y-axis).
---@overload fun(LoveGraphicsTexture, number, number?, number?, number?, number?, number?, number?, numb...)
---@overload fun(LoveGraphicsTexture, number, LoveMathTransform)
---@overload fun(LoveGraphicsTexture, number, LoveGraphicsQuad, LoveMathTransform)
function love.graphics.drawLayer(texture, layerindex, quad, x, y, r, sx, sy, ox, oy, kx, ky) end

--- Draws an ellipse.
---@param mode LoveGraphicsDrawMode
--- How to draw the ellipse.
---@param x number
--- The position of the center along x-axis.
---@param y number
--- The position of the center along y-axis.
---@param radiusx number
--- The radius of the ellipse along the x-axis (half the ellipse's width).
---@param radiusy number
--- The radius of the ellipse along the y-axis (half the ellipse's height).
---@param segments number
--- The number of segments used for drawing the ellipse.
---@overload fun(LoveGraphicsDrawMode, number, number, number, number)
function love.graphics.ellipse(mode, x, y, radiusx, radiusy, segments) end

--- Immediately renders any pending automatically batched draws. LÖVE will call this function intern...
function love.graphics.flushBatch() end

--- Gets the current background color. In versions prior to 11.0, color component values were within ...
---@return number
--- The red component (0-1).
---@return number
--- The green component (0-1).
---@return number
--- The blue component (0-1).
---@return number
--- The alpha component (0-1).
function love.graphics.getBackgroundColor() end

--- Gets the blending mode.
---@return LoveGraphicsBlendMode
--- The current blend mode.
---@return LoveGraphicsBlendAlphaMode
--- The current blend alpha mode – it determines how the alpha of drawn objects...
function love.graphics.getBlendMode() end

--- Gets the current target Canvas.
---@return LoveGraphicsCanvas
--- The Canvas set by setCanvas. Returns nil if drawing to the real screen.
function love.graphics.getCanvas() end

--- Gets the available Canvas formats, and whether each is supported.
---@param readable boolean
--- If true, the returned formats will only be indicated as supported if readable...
---@overload fun()
---@return table
--- A table containing CanvasFormats as keys, and a boolean indicating whether th...
function love.graphics.getCanvasFormats(readable) end

--- Gets the current color. In versions prior to 11.0, color component values were within the range o...
---@return number
--- The red component (0-1).
---@return number
--- The green component (0-1).
---@return number
--- The blue component (0-1).
---@return number
--- The alpha component (0-1).
function love.graphics.getColor() end

--- Gets the active color components used when drawing. Normally all 4 components are active unless l...
---@return boolean
--- Whether the red color component is active when rendering.
---@return boolean
--- Whether the green color component is active when rendering.
---@return boolean
--- Whether the blue color component is active when rendering.
---@return boolean
--- Whether the alpha color component is active when rendering.
function love.graphics.getColorMask() end

--- Gets the DPI scale factor of the window. The DPI scale factor represents relative pixel density. ...
---@return number
--- The pixel scale factor associated with the window.
function love.graphics.getDPIScale() end

--- Returns the default scaling filters used with Images, Canvases, and Fonts.
---@return LoveGraphicsFilterMode
--- Filter mode used when scaling the image down.
---@return LoveGraphicsFilterMode
--- Filter mode used when scaling the image up.
---@return number
--- Maximum amount of Anisotropic Filtering used.
function love.graphics.getDefaultFilter() end

--- Gets the current depth test mode and whether writing to the depth buffer is enabled. This is low-...
---@return LoveGraphicsCompareMode
--- Depth comparison mode used for depth testing.
---@return boolean
--- Whether to write update / write values to the depth buffer when rendering.
function love.graphics.getDepthMode() end

--- Gets the width and height in pixels of the window.
---@return number
--- The width of the window.
---@return number
--- The height of the window.
function love.graphics.getDimensions() end

--- Gets the current Font object.
---@return LoveGraphicsFont
--- The current Font. Automatically creates and sets the default font, if none is...
function love.graphics.getFont() end

--- Gets whether triangles with clockwise- or counterclockwise-ordered vertices are considered front-...
---@return LoveGraphicsVertexWinding
--- The winding mode being used. The default winding is counterclockwise ('ccw').
function love.graphics.getFrontFaceWinding() end

--- Gets the height in pixels of the window.
---@return number
--- The height of the window.
function love.graphics.getHeight() end

--- Gets the raw and compressed pixel formats usable for Images, and whether each is supported.
---@return table
--- A table containing PixelFormats as keys, and a boolean indicating whether the...
function love.graphics.getImageFormats() end

--- Gets the line join style.
---@return LoveGraphicsLineJoin
--- The LineJoin style.
function love.graphics.getLineJoin() end

--- Gets the line style.
---@return LoveGraphicsLineStyle
--- The current line style.
function love.graphics.getLineStyle() end

--- Gets the current line width.
---@return number
--- The current line width.
function love.graphics.getLineWidth() end

--- Gets whether back-facing triangles in a Mesh are culled. Mesh face culling is designed for use wi...
---@return LoveGraphicsCullMode
--- The Mesh face culling mode in use (whether to render everything, cull back-fa...
function love.graphics.getMeshCullMode() end

--- Gets the width and height in pixels of the window. love.graphics.getDimensions gets the dimension...
---@return number
--- The width of the window in pixels.
---@return number
--- The height of the window in pixels.
function love.graphics.getPixelDimensions() end

--- Gets the height in pixels of the window. The graphics coordinate system and DPI scale factor, rat...
---@return number
--- The height of the window in pixels.
function love.graphics.getPixelHeight() end

--- Gets the width in pixels of the window. The graphics coordinate system and DPI scale factor, rath...
---@return number
--- The width of the window in pixels.
function love.graphics.getPixelWidth() end

--- Gets the point size.
---@return number
--- The current point size.
function love.graphics.getPointSize() end

--- Gets information about the system's video card and drivers.
---@return string
--- The name of the renderer, e.g. 'OpenGL' or 'OpenGL ES'.
---@return string
--- The version of the renderer with some extra driver-dependent version info, e....
---@return string
--- The name of the graphics card vendor, e.g. 'Intel Inc'.
---@return string
--- The name of the graphics card, e.g. 'Intel HD Graphics 3000 OpenGL Engine'.
function love.graphics.getRendererInfo() end

--- Gets the current scissor box.
---@return number
--- The x-component of the top-left point of the box.
---@return number
--- The y-component of the top-left point of the box.
---@return number
--- The width of the box.
---@return number
--- The height of the box.
function love.graphics.getScissor() end

--- Gets the current Shader. Returns nil if none is set.
---@return LoveGraphicsShader
--- The currently active Shader, or nil if none is set.
function love.graphics.getShader() end

--- Gets the current depth of the transform / state stack (the number of pushes without corresponding...
---@return number
--- The current depth of the transform and state love.graphics stack.
function love.graphics.getStackDepth() end

--- Gets performance-related rendering statistics.
---@param stats table
--- A table which will be filled in with the stat fields below.
---@overload fun()
---@return table
--- The table that was passed in above, now containing the following fields:
function love.graphics.getStats(stats) end

--- Gets the current stencil test configuration. When stencil testing is enabled, the geometry of eve...
---@return LoveGraphicsCompareMode
--- The type of comparison that is made for each pixel. Will be 'always' if stenc...
---@return number
--- The value used when comparing with the stencil value of each pixel.
function love.graphics.getStencilTest() end

--- Gets the optional graphics features and whether they're supported on the system. Some older or lo...
---@return table
--- A table containing GraphicsFeature keys, and boolean values indicating whethe...
function love.graphics.getSupported() end

--- Gets the system-dependent maximum values for love.graphics features.
---@return table
--- A table containing GraphicsLimit keys, and number values.
function love.graphics.getSystemLimits() end

--- Gets the available texture types, and whether each is supported.
---@return table
--- A table containing TextureTypes as keys, and a boolean indicating whether the...
function love.graphics.getTextureTypes() end

--- Gets the width in pixels of the window.
---@return number
--- The width of the window.
function love.graphics.getWidth() end

--- Sets the scissor to the rectangle created by the intersection of the specified rectangle with the...
---@param x number
--- The x-coordinate of the upper left corner of the rectangle to intersect with ...
---@param y number
--- The y-coordinate of the upper left corner of the rectangle to intersect with ...
---@param width number
--- The width of the rectangle to intersect with the existing scissor rectangle.
---@param height number
--- The height of the rectangle to intersect with the existing scissor rectangle.
function love.graphics.intersectScissor(x, y, width, height) end

--- Converts the given 2D position from screen-space into global coordinates. This effectively applie...
---@param screenX number
--- The x component of the screen-space position.
---@param screenY number
--- The y component of the screen-space position.
---@return number
--- The x component of the position in global coordinates.
---@return number
--- The y component of the position in global coordinates.
function love.graphics.inverseTransformPoint(screenX, screenY) end

--- Gets whether the graphics module is able to be used. If it is not active, love.graphics function ...
---@return boolean
--- Whether the graphics module is active and able to be used.
function love.graphics.isActive() end

--- Gets whether gamma-correct rendering is supported and enabled. It can be enabled by setting t.gam...
---@return boolean
--- True if gamma-correct rendering is supported and was enabled in love.conf, fa...
function love.graphics.isGammaCorrect() end

--- Gets whether wireframe mode is used when drawing.
---@return boolean
--- True if wireframe lines are used when drawing, false if it's not.
function love.graphics.isWireframe() end

--- Draws lines between points.
---@param x1 number
--- The position of first point on the x-axis.
---@param y1 number
--- The position of first point on the y-axis.
---@param x2 number
--- The position of second point on the x-axis.
---@param y2 number
--- The position of second point on the y-axis.
---@param ___ number
--- You can continue passing point positions to draw a polyline.
---@overload fun(table)
function love.graphics.line(x1, y1, x2, y2, ___) end

--- Creates a new array Image. An array image / array texture is a single object which contains multi...
---@param slices table
--- A table containing filepaths to images (or File, FileData, ImageData, or Comp...
---@param settings? table
--- Optional table of settings to configure the array image, containing the follo...
---@return LoveGraphicsImage
--- An Array Image object.
function love.graphics.newArrayImage(slices, settings) end

--- Creates a new Canvas object for offscreen rendering.
---@param width number
--- The desired width of the Canvas.
---@param height number
--- The desired height of the Canvas.
---@param layers number
--- The number of array layers (if the Canvas is an Array Texture), or the volume...
---@param settings? table
--- A table containing the given fields:
---@overload fun()
---@overload fun(number, number)
---@overload fun(number, number, table?)
---@return LoveGraphicsCanvas
--- A new Canvas with specified width and height.
function love.graphics.newCanvas(width, height, layers, settings) end

--- Creates a new cubemap Image. Cubemap images have 6 faces (sides) which represent a cube. They can...
---@param filename string
--- The filepath to a cubemap image file (or a File, FileData, or ImageData).
---@param settings? table
--- Optional table of settings to configure the cubemap image, containing the fol...
---@return LoveGraphicsImage
--- An cubemap Image object.
function love.graphics.newCubeImage(filename, settings) end

--- Creates a new Font from a TrueType Font or BMFont file. Created fonts are not cached, in that cal...
---@param filename string
--- The filepath to the TrueType font file.
---@param size number
--- The size of the font in pixels.
---@param hinting? LoveFontHintingMode
--- True Type hinting mode.
---@param dpiscale? number
--- The DPI scale factor of the font.
---@overload fun(string)
---@overload fun(string, string)
---@overload fun(number?, LoveFontHintingMode?, number?)
---@return LoveGraphicsFont
--- A Font object which can be used to draw text on screen.
function love.graphics.newFont(filename, size, hinting, dpiscale) end

--- Creates a new Image from a filepath, FileData, an ImageData, or a CompressedImageData, and option...
---@param filename string
--- The filepath to the image file.
---@param settings? table
--- A table containing the following fields:
---@return LoveGraphicsImage
--- A new Image object which can be drawn on screen.
function love.graphics.newImage(filename, settings) end

--- Creates a new specifically formatted image. In versions prior to 0.9.0, LÖVE expects ISO 8859-1 ...
---@param filename string
--- The filepath to the image file.
---@param glyphs string
--- A string of the characters in the image in order from left to right.
---@param extraspacing? number
--- Additional spacing (positive or negative) to apply to each glyph in the Font.
---@return LoveGraphicsFont
--- A Font object which can be used to draw text on screen.
function love.graphics.newImageFont(filename, glyphs, extraspacing) end

--- Creates a new Mesh. Use Mesh:setTexture if the Mesh should be textured with an Image or Canvas wh...
---@param vertexformat table
--- A table in the form of {attribute, ...}. Each attribute is a table which spec...
---@param vertices table
--- The table filled with vertex information tables for each vertex, in the form ...
---@param mode? LoveGraphicsMeshDrawMode
--- How the vertices are used when drawing. The default mode 'fan' is sufficient ...
---@param usage? LoveGraphicsSpriteBatchUsage
--- The expected usage of the Mesh. The specified usage mode affects the Mesh's m...
---@overload fun(table, LoveGraphicsMeshDrawMode?, LoveGraphicsSpriteBatchUsage?)
---@return LoveGraphicsMesh
--- The new mesh.
function love.graphics.newMesh(vertexformat, vertices, mode, usage) end

--- Creates a new ParticleSystem.
---@param image LoveGraphicsImage
--- The image to use.
---@param buffer? number
--- The max number of particles at the same time.
---@return LoveGraphicsParticleSystem
--- A new ParticleSystem.
function love.graphics.newParticleSystem(image, buffer) end

--- Creates a new Quad. The purpose of a Quad is to use a fraction of an image to draw objects, as op...
---@param x number
--- The top-left position in the Image along the x-axis.
---@param y number
--- The top-left position in the Image along the y-axis.
---@param width number
--- The width of the Quad in the Image. (Must be greater than 0.)
---@param height number
--- The height of the Quad in the Image. (Must be greater than 0.)
---@param sw number
--- The reference width, the width of the Image. (Must be greater than 0.)
---@param sh number
--- The reference height, the height of the Image. (Must be greater than 0.)
---@overload fun(number, number, number, number, LoveGraphicsTexture)
---@return LoveGraphicsQuad
--- The new Quad.
function love.graphics.newQuad(x, y, width, height, sw, sh) end

--- Creates a new Shader object for hardware-accelerated vertex and pixel effects. A Shader contains ...
---@param pixelcode string
--- The pixel shader code, or a filename pointing to a file with the code.
---@param vertexcode string
--- The vertex shader code, or a filename pointing to a file with the code.
---@overload fun(string)
---@return LoveGraphicsShader
--- A Shader object for use in drawing operations.
function love.graphics.newShader(pixelcode, vertexcode) end

--- Creates a new SpriteBatch object.
---@param image LoveGraphicsImage
--- The Image to use for the sprites.
---@param maxsprites? number
--- The maximum number of sprites that the SpriteBatch can contain at any given t...
---@param usage? LoveGraphicsSpriteBatchUsage
--- The expected usage of the SpriteBatch. The specified usage mode affects the S...
---@overload fun(LoveGraphicsImage, number?)
---@return LoveGraphicsSpriteBatch
--- The new SpriteBatch.
function love.graphics.newSpriteBatch(image, maxsprites, usage) end

--- Creates a new drawable Text object.
---@param font LoveGraphicsFont
--- The font to use for the text.
---@param textstring? string
--- The initial string of text that the new Text object will contain. May be nil.
---@return LoveGraphicsText
--- The new drawable Text object.
function love.graphics.newText(font, textstring) end

--- Creates a new drawable Video. Currently only Ogg Theora video files are supported.
---@param filename string
--- The file path to the Ogg Theora video file (or VideoStream).
---@param settings? table
--- A table containing the following fields:
---@overload fun(string)
---@return LoveGraphicsVideo
--- A new Video.
function love.graphics.newVideo(filename, settings) end

--- Creates a new volume (3D) Image. Volume images are 3D textures with width, height, and depth. The...
---@param layers table
--- A table containing filepaths to images (or File, FileData, ImageData, or Comp...
---@param settings? table
--- Optional table of settings to configure the volume image, containing the foll...
---@return LoveGraphicsImage
--- A volume Image object.
function love.graphics.newVolumeImage(layers, settings) end

--- Resets the current coordinate transformation. This function is always used to reverse any previou...
function love.graphics.origin() end

--- Draws one or more points.
---@param x number
--- The position of the first point on the x-axis.
---@param y number
--- The position of the first point on the y-axis.
---@param ___ number
--- The x and y coordinates of additional points.
---@overload fun(table)
function love.graphics.points(x, y, ___) end

--- Draw a polygon. Following the mode argument, this function can accept multiple numeric arguments ...
---@param mode LoveGraphicsDrawMode
--- How to draw the polygon.
---@param ___ number
--- The vertices of the polygon.
function love.graphics.polygon(mode, ___) end

--- Pops the current coordinate transformation from the transformation stack. This function is always...
function love.graphics.pop() end

--- Displays the results of drawing operations on the screen. This function is used when writing your...
function love.graphics.present() end

--- Draws text on screen. If no Font is set, one will be created and set (once) if needed. As of LOVE...
---@param text string
--- The text to draw.
---@param x? number
--- The position to draw the object (x-axis).
---@param y? number
--- The position to draw the object (y-axis).
---@param r? number
--- Orientation (radians).
---@param sx? number
--- Scale factor (x-axis).
---@param sy? number
--- Scale factor (y-axis).
---@param ox? number
--- Origin offset (x-axis).
---@param oy? number
--- Origin offset (y-axis).
---@param kx? number
--- Shearing factor (x-axis).
---@param ky? number
--- Shearing factor (y-axis).
---@overload fun(string, LoveMathTransform)
---@overload fun(string, LoveGraphicsFont, LoveMathTransform)
function love.graphics.print(text, x, y, r, sx, sy, ox, oy, kx, ky) end

--- Draws formatted text, with word wrap and alignment. See additional notes in love.graphics.print. ...
---@param text string
--- A text string.
---@param font LoveGraphicsFont
--- The Font object to use.
---@param x number
--- The position on the x-axis.
---@param y number
--- The position on the y-axis.
---@param limit number
--- Wrap the line after this many horizontal pixels.
---@param align? LoveGraphicsAlignMode
--- The alignment.
---@param r? number
--- Orientation (radians).
---@param sx? number
--- Scale factor (x-axis).
---@param sy? number
--- Scale factor (y-axis).
---@param ox? number
--- Origin offset (x-axis).
---@param oy? number
--- Origin offset (y-axis).
---@param kx? number
--- Shearing factor (x-axis).
---@param ky? number
--- Shearing factor (y-axis).
---@overload fun(string, number, number, number, LoveGraphicsAlignMode?, number?, number?, number?, numb...)
---@overload fun(string, LoveMathTransform, number, LoveGraphicsAlignMode?)
---@overload fun(string, LoveGraphicsFont, LoveMathTransform, number, LoveGraphicsAlignMode?)
function love.graphics.printf(text, font, x, y, limit, align, r, sx, sy, ox, oy, kx, ky) end

--- Copies and pushes the current coordinate transformation to the transformation stack. This functio...
---@param stack LoveGraphicsStackType
--- The type of stack to push (e.g. just transformation state, or all love.graphi...
---@overload fun()
function love.graphics.push(stack) end

--- Draws a rectangle.
---@param mode LoveGraphicsDrawMode
--- How to draw the rectangle.
---@param x number
--- The position of top-left corner along the x-axis.
---@param y number
--- The position of top-left corner along the y-axis.
---@param width number
--- Width of the rectangle.
---@param height number
--- Height of the rectangle.
---@param rx number
--- The x-axis radius of each round corner. Cannot be greater than half the recta...
---@param ry? number
--- The y-axis radius of each round corner. Cannot be greater than half the recta...
---@param segments? number
--- The number of segments used for drawing the round corners. A default amount w...
---@overload fun(LoveGraphicsDrawMode, number, number, number, number)
function love.graphics.rectangle(mode, x, y, width, height, rx, ry, segments) end

--- Replaces the current coordinate transformation with the given Transform object.
---@param transform LoveMathTransform
--- The Transform object to replace the current graphics coordinate transform with.
function love.graphics.replaceTransform(transform) end

--- Resets the current graphics settings. Calling reset makes the current drawing color white, the cu...
function love.graphics.reset() end

--- Rotates the coordinate system in two dimensions. Calling this function affects all future drawing...
---@param angle number
--- The amount to rotate the coordinate system in radians.
function love.graphics.rotate(angle) end

--- Scales the coordinate system in two dimensions. By default the coordinate system in LÖVE corresp...
---@param sx number
--- The scaling in the direction of the x-axis.
---@param sy? number
--- The scaling in the direction of the y-axis. If omitted, it defaults to same a...
function love.graphics.scale(sx, sy) end

--- Sets the background color.
---@param red number
--- The red component (0-1).
---@param green number
--- The green component (0-1).
---@param blue number
--- The blue component (0-1).
---@param alpha? number
--- The alpha component (0-1).
---@overload fun(table)
function love.graphics.setBackgroundColor(red, green, blue, alpha) end

--- Sets the blending mode.
---@param mode LoveGraphicsBlendMode
--- The blend mode to use.
---@param alphamode? LoveGraphicsBlendAlphaMode
--- What to do with the alpha of drawn objects when blending.
---@overload fun(LoveGraphicsBlendMode)
function love.graphics.setBlendMode(mode, alphamode) end

--- Captures drawing operations to a Canvas.
---@param canvas1 LoveGraphicsCanvas
--- The first render target.
---@param canvas2 LoveGraphicsCanvas
--- The second render target.
---@param ___ LoveGraphicsCanvas
--- More canvases.
---@overload fun(LoveGraphicsCanvas, number?)
---@overload fun()
---@overload fun(table)
function love.graphics.setCanvas(canvas1, canvas2, ___) end

--- Sets the color used for drawing. In versions prior to 11.0, color component values were within th...
---@param red number
--- The amount of red.
---@param green number
--- The amount of green.
---@param blue number
--- The amount of blue.
---@param alpha? number
--- The amount of alpha. The alpha value will be applied to all subsequent draw o...
---@overload fun(table)
function love.graphics.setColor(red, green, blue, alpha) end

--- Sets the color mask. Enables or disables specific color components when rendering and clearing th...
---@param red boolean
--- Render red component.
---@param green boolean
--- Render green component.
---@param blue boolean
--- Render blue component.
---@param alpha boolean
--- Render alpha component.
---@overload fun()
function love.graphics.setColorMask(red, green, blue, alpha) end

--- Sets the default scaling filters used with Images, Canvases, and Fonts.
---@param min LoveGraphicsFilterMode
--- Filter mode used when scaling the image down.
---@param mag? LoveGraphicsFilterMode
--- Filter mode used when scaling the image up.
---@param anisotropy? number
--- Maximum amount of Anisotropic Filtering used.
function love.graphics.setDefaultFilter(min, mag, anisotropy) end

--- Configures depth testing and writing to the depth buffer. This is low-level functionality designe...
---@param comparemode LoveGraphicsCompareMode
--- Depth comparison mode used for depth testing.
---@param write boolean
--- Whether to write update / write values to the depth buffer when rendering.
---@overload fun()
function love.graphics.setDepthMode(comparemode, write) end

--- Set an already-loaded Font as the current font or create and load a new one from the file and siz...
---@param font LoveGraphicsFont
--- The Font object to use.
function love.graphics.setFont(font) end

--- Sets whether triangles with clockwise- or counterclockwise-ordered vertices are considered front-...
---@param winding LoveGraphicsVertexWinding
--- The winding mode to use. The default winding is counterclockwise ('ccw').
function love.graphics.setFrontFaceWinding(winding) end

--- Sets the line join style. See LineJoin for the possible options.
---@param join LoveGraphicsLineJoin
--- The LineJoin to use.
function love.graphics.setLineJoin(join) end

--- Sets the line style.
---@param style LoveGraphicsLineStyle
--- The LineStyle to use. Line styles include smooth and rough.
function love.graphics.setLineStyle(style) end

--- Sets the line width.
---@param width number
--- The width of the line.
function love.graphics.setLineWidth(width) end

--- Sets whether back-facing triangles in a Mesh are culled. This is designed for use with low level ...
---@param mode LoveGraphicsCullMode
--- The Mesh face culling mode to use (whether to render everything, cull back-fa...
function love.graphics.setMeshCullMode(mode) end

--- Creates and sets a new Font.
---@param filename string
--- The path and name of the file with the font.
---@param size? number
--- The size of the font.
---@overload fun(number?)
---@return LoveGraphicsFont
--- The new font.
function love.graphics.setNewFont(filename, size) end

--- Sets the point size.
---@param size number
--- The new point size.
function love.graphics.setPointSize(size) end

--- Sets or disables scissor. The scissor limits the drawing area to a specified rectangle. This affe...
---@param x number
--- x coordinate of upper left corner.
---@param y number
--- y coordinate of upper left corner.
---@param width number
--- width of clipping rectangle.
---@param height number
--- height of clipping rectangle.
---@overload fun()
function love.graphics.setScissor(x, y, width, height) end

--- Sets or resets a Shader as the current pixel effect or vertex shaders. All drawing operations unt...
---@param shader LoveGraphicsShader
--- The new shader.
---@overload fun()
function love.graphics.setShader(shader) end

--- Configures or disables stencil testing. When stencil testing is enabled, the geometry of everythi...
---@param comparemode LoveGraphicsCompareMode
--- The type of comparison to make for each pixel.
---@param comparevalue number
--- The value to use when comparing with the stencil value of each pixel. Must be...
---@overload fun()
function love.graphics.setStencilTest(comparemode, comparevalue) end

--- Sets whether wireframe lines will be used when drawing.
---@param enable boolean
--- True to enable wireframe mode when drawing, false to disable it.
function love.graphics.setWireframe(enable) end

--- Shears the coordinate system.
---@param kx number
--- The shear factor on the x-axis.
---@param ky number
--- The shear factor on the y-axis.
function love.graphics.shear(kx, ky) end

--- Draws geometry as a stencil. The geometry drawn by the supplied function sets invisible stencil v...
---@param stencilfunction function
--- Function which draws geometry. The stencil values of pixels, rather than the ...
---@param action? LoveGraphicsStencilAction
--- How to modify any stencil values of pixels that are touched by what's drawn i...
---@param value? number
--- The new stencil value to use for pixels if the 'replace' stencil action is us...
---@param keepvalues? boolean
--- True to preserve old stencil values of pixels, false to re-set every pixel's ...
function love.graphics.stencil(stencilfunction, action, value, keepvalues) end

--- Converts the given 2D position from global coordinates into screen-space. This effectively applie...
---@param globalX number
--- The x component of the position in global coordinates.
---@param globalY number
--- The y component of the position in global coordinates.
---@return number
--- The x component of the position with graphics transformations applied.
---@return number
--- The y component of the position with graphics transformations applied.
function love.graphics.transformPoint(globalX, globalY) end

--- Translates the coordinate system in two dimensions. When this function is called with two numbers...
---@param dx number
--- The translation relative to the x-axis.
---@param dy number
--- The translation relative to the y-axis.
function love.graphics.translate(dx, dy) end

--- Validates shader code. Check if specified shader code does not contain any errors.
---@param gles boolean
--- Validate code as GLSL ES shader.
---@param pixelcode string
--- The pixel shader code, or a filename pointing to a file with the code.
---@param vertexcode string
--- The vertex shader code, or a filename pointing to a file with the code.
---@overload fun(boolean, string)
---@return boolean
--- true if specified shader code doesn't contain any errors. false otherwise.
---@return string
--- Reason why shader code validation failed (or nil if validation succeded).
function love.graphics.validateShader(gles, pixelcode, vertexcode) end

--- ------------------------------------------------------------
--- love.image
--- Provides an interface to decode encoded image data.
---@class love.image
love.image = {}

--- Compressed image data formats. Here and here are a couple overviews of many of the formats. Unlik...
---@alias LoveImageCompressedImageFormat
---| 'DXT1' # The DXT1 format. RGB data at 4 bits per pixel (compared to 32 bits ...
---| 'DXT3' # The DXT3 format. RGBA data at 8 bits per pixel. Smooth variations i...
---| 'DXT5' # The DXT5 format. RGBA data at 8 bits per pixel. Recommended for ima...
---| 'BC4' # The BC4 format (also known as 3Dc+ or ATI1.) Stores just the red ch...
---| 'BC4s' # The signed variant of the BC4 format. Same as above but pixel value...
---| 'BC5' # The BC5 format (also known as 3Dc or ATI2.) Stores red and green ch...
---| 'BC5s' # The signed variant of the BC5 format.
---| 'BC6h' # The BC6H format. Stores half-precision floating-point RGB data in t...
---| 'BC6hs' # The signed variant of the BC6H format. Stores RGB data in the range...
---| 'BC7' # The BC7 format (also known as BPTC.) Stores RGB or RGBA data at 8 b...
---| 'ETC1' # The ETC1 format. RGB data at 4 bits per pixel. Suitable for fully o...
---| 'ETC2rgb' # The RGB variant of the ETC2 format. RGB data at 4 bits per pixel. S...
---| 'ETC2rgba' # The RGBA variant of the ETC2 format. RGBA data at 8 bits per pixel....
---| 'ETC2rgba1' # The RGBA variant of the ETC2 format where pixels are either fully t...
---| 'EACr' # The single-channel variant of the EAC format. Stores just the red c...
---| 'EACrs' # The signed single-channel variant of the EAC format. Same as above ...
---| 'EACrg' # The two-channel variant of the EAC format. Stores red and green cha...
---| 'EACrgs' # The signed two-channel variant of the EAC format.
---| 'PVR1rgb2' # The 2 bit per pixel RGB variant of the PVRTC1 format. Stores RGB da...
---| 'PVR1rgb4' # The 4 bit per pixel RGB variant of the PVRTC1 format. Stores RGB da...
---| 'PVR1rgba2' # The 2 bit per pixel RGBA variant of the PVRTC1 format.
---| 'PVR1rgba4' # The 4 bit per pixel RGBA variant of the PVRTC1 format.
---| 'ASTC4x4' # The 4x4 pixels per block variant of the ASTC format. RGBA data at 8...
---| 'ASTC5x4' # The 5x4 pixels per block variant of the ASTC format. RGBA data at 6...
---| 'ASTC5x5' # The 5x5 pixels per block variant of the ASTC format. RGBA data at 5...
---| 'ASTC6x5' # The 6x5 pixels per block variant of the ASTC format. RGBA data at 4...
---| 'ASTC6x6' # The 6x6 pixels per block variant of the ASTC format. RGBA data at 3...
---| 'ASTC8x5' # The 8x5 pixels per block variant of the ASTC format. RGBA data at 3...
---| 'ASTC8x6' # The 8x6 pixels per block variant of the ASTC format. RGBA data at 2...
---| 'ASTC8x8' # The 8x8 pixels per block variant of the ASTC format. RGBA data at 2...
---| 'ASTC10x5' # The 10x5 pixels per block variant of the ASTC format. RGBA data at ...
---| 'ASTC10x6' # The 10x6 pixels per block variant of the ASTC format. RGBA data at ...
---| 'ASTC10x8' # The 10x8 pixels per block variant of the ASTC format. RGBA data at ...
---| 'ASTC10x10' # The 10x10 pixels per block variant of the ASTC format. RGBA data at...
---| 'ASTC12x10' # The 12x10 pixels per block variant of the ASTC format. RGBA data at...
---| 'ASTC12x12' # The 12x12 pixels per block variant of the ASTC format. RGBA data at...

--- Encoded image formats.
---@alias LoveImageImageFormat
---| 'tga' # Targa image format.
---| 'png' # PNG image format.
---| 'jpg' # JPG image format.
---| 'bmp' # BMP image format.

--- Pixel formats for Textures, ImageData, and CompressedImageData.
---@alias LoveImagePixelFormat
---| 'unknown' # Indicates unknown pixel format, used internally.
---| 'normal' # Alias for rgba8, or srgba8 if gamma-correct rendering is enabled.
---| 'hdr' # A format suitable for high dynamic range content - an alias for the...
---| 'r8' # Single-channel (red component) format (8 bpp).
---| 'rg8' # Two channels (red and green components) with 8 bits per channel (16...
---| 'rgba8' # 8 bits per channel (32 bpp) RGBA. Color channel values range from 0...
---| 'srgba8' # gamma-correct version of rgba8.
---| 'r16' # Single-channel (red component) format (16 bpp).
---| 'rg16' # Two channels (red and green components) with 16 bits per channel (3...
---| 'rgba16' # 16 bits per channel (64 bpp) RGBA. Color channel values range from ...
---| 'r16f' # Floating point single-channel format (16 bpp). Color values can ran...
---| 'rg16f' # Floating point two-channel format with 16 bits per channel (32 bpp)...
---| 'rgba16f' # Floating point RGBA with 16 bits per channel (64 bpp). Color values...
---| 'r32f' # Floating point single-channel format (32 bpp).
---| 'rg32f' # Floating point two-channel format with 32 bits per channel (64 bpp).
---| 'rgba32f' # Floating point RGBA with 32 bits per channel (128 bpp).
---| 'la8' # Same as rg8, but accessed as (L, L, L, A)
---| 'rgba4' # 4 bits per channel (16 bpp) RGBA.
---| 'rgb5a1' # RGB with 5 bits each, and a 1-bit alpha channel (16 bpp).
---| 'rgb565' # RGB with 5, 6, and 5 bits each, respectively (16 bpp). There is no ...
---| 'rgb10a2' # RGB with 10 bits per channel, and a 2-bit alpha channel (32 bpp).
---| 'rg11b10f' # Floating point RGB with 11 bits in the red and green channels, and ...
---| 'stencil8' # No depth buffer and 8-bit stencil buffer.
---| 'depth16' # 16-bit depth buffer and no stencil buffer.
---| 'depth24' # 24-bit depth buffer and no stencil buffer.
---| 'depth32f' # 32-bit float depth buffer and no stencil buffer.
---| 'depth24stencil8' # 24-bit depth buffer and 8-bit stencil buffer.
---| 'depth32fstencil8' # 32-bit float depth buffer and 8-bit stencil buffer.
---| 'DXT1' # The DXT1 format. RGB data at 4 bits per pixel (compared to 32 bits ...
---| 'DXT3' # The DXT3 format. RGBA data at 8 bits per pixel. Smooth variations i...
---| 'DXT5' # The DXT5 format. RGBA data at 8 bits per pixel. Recommended for ima...
---| 'BC4' # The BC4 format (also known as 3Dc+ or ATI1.) Stores just the red ch...
---| 'BC4s' # The signed variant of the BC4 format. Same as above but pixel value...
---| 'BC5' # The BC5 format (also known as 3Dc or ATI2.) Stores red and green ch...
---| 'BC5s' # The signed variant of the BC5 format.
---| 'BC6h' # The BC6H format. Stores half-precision floating-point RGB data in t...
---| 'BC6hs' # The signed variant of the BC6H format. Stores RGB data in the range...
---| 'BC7' # The BC7 format (also known as BPTC.) Stores RGB or RGBA data at 8 b...
---| 'ETC1' # The ETC1 format. RGB data at 4 bits per pixel. Suitable for fully o...
---| 'ETC2rgb' # The RGB variant of the ETC2 format. RGB data at 4 bits per pixel. S...
---| 'ETC2rgba' # The RGBA variant of the ETC2 format. RGBA data at 8 bits per pixel....
---| 'ETC2rgba1' # The RGBA variant of the ETC2 format where pixels are either fully t...
---| 'EACr' # The single-channel variant of the EAC format. Stores just the red c...
---| 'EACrs' # The signed single-channel variant of the EAC format. Same as above ...
---| 'EACrg' # The two-channel variant of the EAC format. Stores red and green cha...
---| 'EACrgs' # The signed two-channel variant of the EAC format.
---| 'PVR1rgb2' # The 2 bit per pixel RGB variant of the PVRTC1 format. Stores RGB da...
---| 'PVR1rgb4' # The 4 bit per pixel RGB variant of the PVRTC1 format. Stores RGB da...
---| 'PVR1rgba2' # The 2 bit per pixel RGBA variant of the PVRTC1 format.
---| 'PVR1rgba4' # The 4 bit per pixel RGBA variant of the PVRTC1 format.
---| 'ASTC4x4' # The 4x4 pixels per block variant of the ASTC format. RGBA data at 8...
---| 'ASTC5x4' # The 5x4 pixels per block variant of the ASTC format. RGBA data at 6...
---| 'ASTC5x5' # The 5x5 pixels per block variant of the ASTC format. RGBA data at 5...
---| 'ASTC6x5' # The 6x5 pixels per block variant of the ASTC format. RGBA data at 4...
---| 'ASTC6x6' # The 6x6 pixels per block variant of the ASTC format. RGBA data at 3...
---| 'ASTC8x5' # The 8x5 pixels per block variant of the ASTC format. RGBA data at 3...
---| 'ASTC8x6' # The 8x6 pixels per block variant of the ASTC format. RGBA data at 2...
---| 'ASTC8x8' # The 8x8 pixels per block variant of the ASTC format. RGBA data at 2...
---| 'ASTC10x5' # The 10x5 pixels per block variant of the ASTC format. RGBA data at ...
---| 'ASTC10x6' # The 10x6 pixels per block variant of the ASTC format. RGBA data at ...
---| 'ASTC10x8' # The 10x8 pixels per block variant of the ASTC format. RGBA data at ...
---| 'ASTC10x10' # The 10x10 pixels per block variant of the ASTC format. RGBA data at...
---| 'ASTC12x10' # The 12x10 pixels per block variant of the ASTC format. RGBA data at...
---| 'ASTC12x12' # The 12x12 pixels per block variant of the ASTC format. RGBA data at...

--- Represents compressed image data designed to stay compressed in RAM. CompressedImageData encompas...
---@class LoveImageCompressedImageData
--- (also inherits: Object)
LoveImageCompressedImageData = {}

--- Gets the width and height of the CompressedImageData.
---@param level number
--- A mipmap level. Must be in the range of CompressedImageData:getMipmapCount().
---@overload fun()
---@return number
--- The width of a specific mipmap level of the CompressedImageData.
---@return number
--- The height of a specific mipmap level of the CompressedImageData.
function LoveImageCompressedImageData:getDimensions(level) end

--- Gets the format of the CompressedImageData.
---@return LoveImageCompressedImageFormat
--- The format of the CompressedImageData.
function LoveImageCompressedImageData:getFormat() end

--- Gets the height of the CompressedImageData.
---@param level number
--- A mipmap level. Must be in the range of CompressedImageData:getMipmapCount().
---@overload fun()
---@return number
--- The height of a specific mipmap level of the CompressedImageData.
function LoveImageCompressedImageData:getHeight(level) end

--- Gets the number of mipmap levels in the CompressedImageData. The base mipmap level (original imag...
---@return number
--- The number of mipmap levels stored in the CompressedImageData.
function LoveImageCompressedImageData:getMipmapCount() end

--- Gets the width of the CompressedImageData.
---@param level number
--- A mipmap level. Must be in the range of CompressedImageData:getMipmapCount().
---@overload fun()
---@return number
--- The width of a specific mipmap level of the CompressedImageData.
function LoveImageCompressedImageData:getWidth(level) end

--- Raw (decoded) image data. You can't draw ImageData directly to screen. See Image for that.
---@class LoveImageImageData
--- (also inherits: Object)
LoveImageImageData = {}

--- Encodes the ImageData and optionally writes it to the save directory.
---@param format LoveImageImageFormat
--- The format to encode the image as.
---@param filename? string
--- The filename to write the file to. If nil, no file will be written but the Fi...
---@overload fun(string)
---@return LoveFilesystemFileData
--- The encoded image as a new FileData object.
function LoveImageImageData:encode(format, filename) end

--- Gets the width and height of the ImageData in pixels.
---@return number
--- The width of the ImageData in pixels.
---@return number
--- The height of the ImageData in pixels.
function LoveImageImageData:getDimensions() end

--- Gets the height of the ImageData in pixels.
---@return number
--- The height of the ImageData in pixels.
function LoveImageImageData:getHeight() end

--- Gets the color of a pixel at a specific position in the image. Valid x and y values start at 0 an...
---@param x number
--- The position of the pixel on the x-axis.
---@param y number
--- The position of the pixel on the y-axis.
---@return number
--- The red component (0-1).
---@return number
--- The green component (0-1).
---@return number
--- The blue component (0-1).
---@return number
--- The alpha component (0-1).
function LoveImageImageData:getPixel(x, y) end

--- Gets the width of the ImageData in pixels.
---@return number
--- The width of the ImageData in pixels.
function LoveImageImageData:getWidth() end

--- Transform an image by applying a function to every pixel. This function is a higher-order functio...
---@param pixelFunction function
--- Function to apply to every pixel.
---@param x? number
--- The x-axis of the top-left corner of the area within the ImageData to apply t...
---@param y? number
--- The y-axis of the top-left corner of the area within the ImageData to apply t...
---@param width? number
--- The width of the area within the ImageData to apply the function to.
---@param height? number
--- The height of the area within the ImageData to apply the function to.
function LoveImageImageData:mapPixel(pixelFunction, x, y, width, height) end

--- Paste into ImageData from another source ImageData.
---@param source LoveImageImageData
--- Source ImageData from which to copy.
---@param dx number
--- Destination top-left position on x-axis.
---@param dy number
--- Destination top-left position on y-axis.
---@param sx number
--- Source top-left position on x-axis.
---@param sy number
--- Source top-left position on y-axis.
---@param sw number
--- Source width.
---@param sh number
--- Source height.
function LoveImageImageData:paste(source, dx, dy, sx, sy, sw, sh) end

--- Sets the color of a pixel at a specific position in the image. Valid x and y values start at 0 an...
---@param x number
--- The position of the pixel on the x-axis.
---@param y number
--- The position of the pixel on the y-axis.
---@param r number
--- The red component (0-1).
---@param g number
--- The green component (0-1).
---@param b number
--- The blue component (0-1).
---@param a number
--- The alpha component (0-1).
---@overload fun(number, number, table)
function LoveImageImageData:setPixel(x, y, r, g, b, a) end

--- Gets the pixel format of the ImageData.
---@return LoveImagePixelFormat
--- The pixel format the ImageData was created with.
function LoveImageImageData:getFormat() end

--- Determines whether a file can be loaded as CompressedImageData.
---@param filename string
--- The filename of the potentially compressed image file.
---@return boolean
--- Whether the file can be loaded as CompressedImageData or not.
function love.image.isCompressed(filename) end

--- Create a new CompressedImageData object from a compressed image file. LÖVE supports several comp...
---@param filename string
--- The filename of the compressed image file.
---@return LoveImageCompressedImageData
--- The new CompressedImageData object.
function love.image.newCompressedData(filename) end

--- Creates a new ImageData object.
---@param width number
--- The width of the ImageData.
---@param height number
--- The height of the ImageData.
---@param format? LoveImagePixelFormat
--- The pixel format of the ImageData.
---@param data? string
--- Optional raw byte data to load into the ImageData, in the format specified by...
---@overload fun(number, number)
---@overload fun(number, number, string)
---@overload fun(string)
---@return LoveImageImageData
--- The new ImageData object.
function love.image.newImageData(width, height, format, data) end

--- ------------------------------------------------------------
--- love.joystick
--- Provides an interface to the user's joystick.
---@class love.joystick
love.joystick = {}

--- Virtual gamepad axes.
---@alias LoveJoystickGamepadAxis
---| 'leftx' # The x-axis of the left thumbstick.
---| 'lefty' # The y-axis of the left thumbstick.
---| 'rightx' # The x-axis of the right thumbstick.
---| 'righty' # The y-axis of the right thumbstick.
---| 'triggerleft' # Left analog trigger.
---| 'triggerright' # Right analog trigger.

--- Virtual gamepad buttons.
---@alias LoveJoystickGamepadButton
---| 'a' # Bottom face button (A).
---| 'b' # Right face button (B).
---| 'x' # Left face button (X).
---| 'y' # Top face button (Y).
---| 'back' # Back button.
---| 'guide' # Guide button.
---| 'start' # Start button.
---| 'leftstick' # Left stick click button.
---| 'rightstick' # Right stick click button.
---| 'leftshoulder' # Left bumper.
---| 'rightshoulder' # Right bumper.
---| 'dpup' # D-pad up.
---| 'dpdown' # D-pad down.
---| 'dpleft' # D-pad left.
---| 'dpright' # D-pad right.

--- Joystick hat positions.
---@alias LoveJoystickJoystickHat
---| 'c' # Centered
---| 'd' # Down
---| 'l' # Left
---| 'ld' # Left+Down
---| 'lu' # Left+Up
---| 'r' # Right
---| 'rd' # Right+Down
---| 'ru' # Right+Up
---| 'u' # Up

--- Types of Joystick inputs.
---@alias LoveJoystickJoystickInputType
---| 'axis' # Analog axis.
---| 'button' # Button.
---| 'hat' # 8-direction hat value.

--- Represents a physical joystick.
---@class LoveJoystickJoystick
LoveJoystickJoystick = {}

--- Gets the direction of each axis.
---@return number
--- Direction of axis1.
---@return number
--- Direction of axis2.
---@return number
--- Direction of axisN.
function LoveJoystickJoystick:getAxes() end

--- Gets the direction of an axis.
---@param axis number
--- The index of the axis to be checked.
---@return number
--- Current value of the axis.
function LoveJoystickJoystick:getAxis(axis) end

--- Gets the number of axes on the joystick.
---@return number
--- The number of axes available.
function LoveJoystickJoystick:getAxisCount() end

--- Gets the number of buttons on the joystick.
---@return number
--- The number of buttons available.
function LoveJoystickJoystick:getButtonCount() end

--- Gets the USB vendor ID, product ID, and product version numbers of joystick which consistent acro...
---@return number
--- The USB vendor ID of the joystick.
---@return number
--- The USB product ID of the joystick.
---@return number
--- The product version of the joystick.
function LoveJoystickJoystick:getDeviceInfo() end

--- Gets a stable GUID unique to the type of the physical joystick which does not change over time. F...
---@return string
--- The Joystick type's OS-dependent unique identifier.
function LoveJoystickJoystick:getGUID() end

--- Gets the direction of a virtual gamepad axis. If the Joystick isn't recognized as a gamepad or is...
---@param axis LoveJoystickGamepadAxis
--- The virtual axis to be checked.
---@return number
--- Current value of the axis.
function LoveJoystickJoystick:getGamepadAxis(axis) end

--- Gets the button, axis or hat that a virtual gamepad input is bound to.
---@param axis LoveJoystickGamepadAxis
--- The virtual gamepad axis to get the binding for.
---@return LoveJoystickJoystickInputType
--- The type of input the virtual gamepad axis is bound to.
---@return number
--- The index of the Joystick's button, axis or hat that the virtual gamepad axis...
---@return LoveJoystickJoystickHat
--- The direction of the hat, if the virtual gamepad axis is bound to a hat. nil ...
function LoveJoystickJoystick:getGamepadMapping(axis) end

--- Gets the full gamepad mapping string of this Joystick, or nil if it's not recognized as a gamepad...
---@return string
--- A string containing the Joystick's gamepad mappings, or nil if the Joystick i...
function LoveJoystickJoystick:getGamepadMappingString() end

--- Gets the direction of the Joystick's hat.
---@param hat number
--- The index of the hat to be checked.
---@return LoveJoystickJoystickHat
--- The direction the hat is pushed.
function LoveJoystickJoystick:getHat(hat) end

--- Gets the number of hats on the joystick.
---@return number
--- How many hats the joystick has.
function LoveJoystickJoystick:getHatCount() end

--- Gets the joystick's unique identifier. The identifier will remain the same for the life of the ga...
---@return number
--- The Joystick's unique identifier. Remains the same as long as the game is run...
---@return number
--- Unique instance identifier. Changes every time the Joystick is reconnected. n...
function LoveJoystickJoystick:getID() end

--- Gets the name of the joystick.
---@return string
--- The name of the joystick.
function LoveJoystickJoystick:getName() end

--- Gets the current vibration motor strengths on a Joystick with rumble support.
---@return number
--- Current strength of the left vibration motor on the Joystick.
---@return number
--- Current strength of the right vibration motor on the Joystick.
function LoveJoystickJoystick:getVibration() end

--- Gets whether the Joystick is connected.
---@return boolean
--- True if the Joystick is currently connected, false otherwise.
function LoveJoystickJoystick:isConnected() end

--- Checks if a button on the Joystick is pressed. LÖVE 0.9.0 had a bug which required the button in...
---@param buttonN number
--- The index of a button to check.
---@return boolean
--- True if any supplied button is down, false if not.
function LoveJoystickJoystick:isDown(buttonN) end

--- Gets whether the Joystick is recognized as a gamepad. If this is the case, the Joystick's buttons...
---@return boolean
--- True if the Joystick is recognized as a gamepad, false otherwise.
function LoveJoystickJoystick:isGamepad() end

--- Checks if a virtual gamepad button on the Joystick is pressed. If the Joystick is not recognized ...
---@param buttonN LoveJoystickGamepadButton
--- The gamepad button to check.
---@return boolean
--- True if any supplied button is down, false if not.
function LoveJoystickJoystick:isGamepadDown(buttonN) end

--- Gets whether the Joystick supports vibration.
---@return boolean
--- True if rumble / force feedback vibration is supported on this Joystick, fals...
function LoveJoystickJoystick:isVibrationSupported() end

--- Sets the vibration motor speeds on a Joystick with rumble support. Most common gamepads have this...
---@param left number
--- Strength of the left vibration motor on the Joystick. Must be in the range of 1.
---@param right number
--- Strength of the right vibration motor on the Joystick. Must be in the range o...
---@param duration? number
--- The duration of the vibration in seconds. A negative value means infinite dur...
---@overload fun(number, number)
---@overload fun()
---@return boolean
--- True if the vibration was successfully applied, false if not.
function LoveJoystickJoystick:setVibration(left, right, duration) end

--- Gets the full gamepad mapping string of the Joysticks which have the given GUID, or nil if the GU...
---@param guid string
--- The GUID value to get the mapping string for.
---@return string
--- A string containing the Joystick's gamepad mappings, or nil if the GUID is no...
function love.joystick.getGamepadMappingString(guid) end

--- Gets the number of connected joysticks.
---@return number
--- The number of connected joysticks.
function love.joystick.getJoystickCount() end

--- Gets a list of connected Joysticks.
---@return table
--- The list of currently connected Joysticks.
function love.joystick.getJoysticks() end

--- Loads a gamepad mappings string or file created with love.joystick.saveGamepadMappings. It also r...
---@param filename string
--- The filename to load the mappings string from.
function love.joystick.loadGamepadMappings(filename) end

--- Saves the virtual gamepad mappings of all recognized as gamepads and have either been recently us...
---@param filename string
--- The filename to save the mappings string to.
---@overload fun()
---@return string
--- The mappings string that was written to the file.
function love.joystick.saveGamepadMappings(filename) end

--- Binds a virtual gamepad input to a button, axis or hat for all Joysticks of a certain type. For e...
---@param guid string
--- The OS-dependent GUID for the type of Joystick the binding will affect.
---@param button LoveJoystickGamepadButton
--- The virtual gamepad button to bind.
---@param inputtype LoveJoystickJoystickInputType
--- The type of input to bind the virtual gamepad button to.
---@param inputindex number
--- The index of the axis, button, or hat to bind the virtual gamepad button to.
---@param hatdir? LoveJoystickJoystickHat
--- The direction of the hat, if the virtual gamepad button will be bound to a ha...
---@return boolean
--- Whether the virtual gamepad button was successfully bound.
function love.joystick.setGamepadMapping(guid, button, inputtype, inputindex, hatdir) end

--- ------------------------------------------------------------
--- love.keyboard
--- Provides an interface to the user's keyboard.
---@class love.keyboard
love.keyboard = {}

--- All the keys you can press. Note that some keys may not be available on your keyboard or system.
---@alias LoveKeyboardKeyConstant
---| 'a' # The A key
---| 'b' # The B key
---| 'c' # The C key
---| 'd' # The D key
---| 'e' # The E key
---| 'f' # The F key
---| 'g' # The G key
---| 'h' # The H key
---| 'i' # The I key
---| 'j' # The J key
---| 'k' # The K key
---| 'l' # The L key
---| 'm' # The M key
---| 'n' # The N key
---| 'o' # The O key
---| 'p' # The P key
---| 'q' # The Q key
---| 'r' # The R key
---| 's' # The S key
---| 't' # The T key
---| 'u' # The U key
---| 'v' # The V key
---| 'w' # The W key
---| 'x' # The X key
---| 'y' # The Y key
---| 'z' # The Z key
---| '0' # The zero key
---| '1' # The one key
---| '2' # The two key
---| '3' # The three key
---| '4' # The four key
---| '5' # The five key
---| '6' # The six key
---| '7' # The seven key
---| '8' # The eight key
---| '9' # The nine key
---| 'space' # Space key
---| '!' # Exclamation mark key
---| '"' # Double quote key
---| '#' # Hash key
---| '$' # Dollar key
---| '&' # Ampersand key
---| ''' # Single quote key
---| '(' # Left parenthesis key
---| ')' # Right parenthesis key
---| '*' # Asterisk key
---| '+' # Plus key
---| ',' # Comma key
---| '-' # Hyphen-minus key
---| '.' # Full stop key
---| '/' # Slash key
---| ':' # Colon key
---| ';' # Semicolon key
---| '<' # Less-than key
---| '=' # Equal key
---| '>' # Greater-than key
---| '?' # Question mark key
---| '@' # At sign key
---| '[' # Left square bracket key
---| '\' # Backslash key
---| ']' # Right square bracket key
---| '^' # Caret key
---| '_' # Underscore key
---| '`' # Grave accent key
---| 'kp0' # The numpad zero key
---| 'kp1' # The numpad one key
---| 'kp2' # The numpad two key
---| 'kp3' # The numpad three key
---| 'kp4' # The numpad four key
---| 'kp5' # The numpad five key
---| 'kp6' # The numpad six key
---| 'kp7' # The numpad seven key
---| 'kp8' # The numpad eight key
---| 'kp9' # The numpad nine key
---| 'kp.' # The numpad decimal point key
---| 'kp/' # The numpad division key
---| 'kp*' # The numpad multiplication key
---| 'kp-' # The numpad substraction key
---| 'kp+' # The numpad addition key
---| 'kpenter' # The numpad enter key
---| 'kp=' # The numpad equals key
---| 'up' # Up cursor key
---| 'down' # Down cursor key
---| 'right' # Right cursor key
---| 'left' # Left cursor key
---| 'home' # Home key
---| 'end' # End key
---| 'pageup' # Page up key
---| 'pagedown' # Page down key
---| 'insert' # Insert key
---| 'backspace' # Backspace key
---| 'tab' # Tab key
---| 'clear' # Clear key
---| 'return' # Return key
---| 'delete' # Delete key
---| 'f1' # The 1st function key
---| 'f2' # The 2nd function key
---| 'f3' # The 3rd function key
---| 'f4' # The 4th function key
---| 'f5' # The 5th function key
---| 'f6' # The 6th function key
---| 'f7' # The 7th function key
---| 'f8' # The 8th function key
---| 'f9' # The 9th function key
---| 'f10' # The 10th function key
---| 'f11' # The 11th function key
---| 'f12' # The 12th function key
---| 'f13' # The 13th function key
---| 'f14' # The 14th function key
---| 'f15' # The 15th function key
---| 'numlock' # Num-lock key
---| 'capslock' # Caps-lock key
---| 'scrollock' # Scroll-lock key
---| 'rshift' # Right shift key
---| 'lshift' # Left shift key
---| 'rctrl' # Right control key
---| 'lctrl' # Left control key
---| 'ralt' # Right alt key
---| 'lalt' # Left alt key
---| 'rmeta' # Right meta key
---| 'lmeta' # Left meta key
---| 'lsuper' # Left super key
---| 'rsuper' # Right super key
---| 'mode' # Mode key
---| 'compose' # Compose key
---| 'pause' # Pause key
---| 'escape' # Escape key
---| 'help' # Help key
---| 'print' # Print key
---| 'sysreq' # System request key
---| 'break' # Break key
---| 'menu' # Menu key
---| 'power' # Power key
---| 'euro' # Euro (&euro;) key
---| 'undo' # Undo key
---| 'www' # WWW key
---| 'mail' # Mail key
---| 'calculator' # Calculator key
---| 'appsearch' # Application search key
---| 'apphome' # Application home key
---| 'appback' # Application back key
---| 'appforward' # Application forward key
---| 'apprefresh' # Application refresh key
---| 'appbookmarks' # Application bookmarks key

--- Keyboard scancodes. Scancodes are keyboard layout-independent, so the scancode "w" will be genera...
---@alias LoveKeyboardScancode
---| 'a' # The 'A' key on an American layout.
---| 'b' # The 'B' key on an American layout.
---| 'c' # The 'C' key on an American layout.
---| 'd' # The 'D' key on an American layout.
---| 'e' # The 'E' key on an American layout.
---| 'f' # The 'F' key on an American layout.
---| 'g' # The 'G' key on an American layout.
---| 'h' # The 'H' key on an American layout.
---| 'i' # The 'I' key on an American layout.
---| 'j' # The 'J' key on an American layout.
---| 'k' # The 'K' key on an American layout.
---| 'l' # The 'L' key on an American layout.
---| 'm' # The 'M' key on an American layout.
---| 'n' # The 'N' key on an American layout.
---| 'o' # The 'O' key on an American layout.
---| 'p' # The 'P' key on an American layout.
---| 'q' # The 'Q' key on an American layout.
---| 'r' # The 'R' key on an American layout.
---| 's' # The 'S' key on an American layout.
---| 't' # The 'T' key on an American layout.
---| 'u' # The 'U' key on an American layout.
---| 'v' # The 'V' key on an American layout.
---| 'w' # The 'W' key on an American layout.
---| 'x' # The 'X' key on an American layout.
---| 'y' # The 'Y' key on an American layout.
---| 'z' # The 'Z' key on an American layout.
---| '1' # The '1' key on an American layout.
---| '2' # The '2' key on an American layout.
---| '3' # The '3' key on an American layout.
---| '4' # The '4' key on an American layout.
---| '5' # The '5' key on an American layout.
---| '6' # The '6' key on an American layout.
---| '7' # The '7' key on an American layout.
---| '8' # The '8' key on an American layout.
---| '9' # The '9' key on an American layout.
---| '0' # The '0' key on an American layout.
---| 'return' # The 'return' / 'enter' key on an American layout.
---| 'escape' # The 'escape' key on an American layout.
---| 'backspace' # The 'backspace' key on an American layout.
---| 'tab' # The 'tab' key on an American layout.
---| 'space' # The spacebar on an American layout.
---| '-' # The minus key on an American layout.
---| '=' # The equals key on an American layout.
---| '[' # The left-bracket key on an American layout.
---| ']' # The right-bracket key on an American layout.
---| '\' # The backslash key on an American layout.
---| 'nonus#' # The non-U.S. hash scancode.
---| ';' # The semicolon key on an American layout.
---| ''' # The apostrophe key on an American layout.
---| '`' # The back-tick / grave key on an American layout.
---| ',' # The comma key on an American layout.
---| '.' # The period key on an American layout.
---| '/' # The forward-slash key on an American layout.
---| 'capslock' # The capslock key on an American layout.
---| 'f1' # The F1 key on an American layout.
---| 'f2' # The F2 key on an American layout.
---| 'f3' # The F3 key on an American layout.
---| 'f4' # The F4 key on an American layout.
---| 'f5' # The F5 key on an American layout.
---| 'f6' # The F6 key on an American layout.
---| 'f7' # The F7 key on an American layout.
---| 'f8' # The F8 key on an American layout.
---| 'f9' # The F9 key on an American layout.
---| 'f10' # The F10 key on an American layout.
---| 'f11' # The F11 key on an American layout.
---| 'f12' # The F12 key on an American layout.
---| 'f13' # The F13 key on an American layout.
---| 'f14' # The F14 key on an American layout.
---| 'f15' # The F15 key on an American layout.
---| 'f16' # The F16 key on an American layout.
---| 'f17' # The F17 key on an American layout.
---| 'f18' # The F18 key on an American layout.
---| 'f19' # The F19 key on an American layout.
---| 'f20' # The F20 key on an American layout.
---| 'f21' # The F21 key on an American layout.
---| 'f22' # The F22 key on an American layout.
---| 'f23' # The F23 key on an American layout.
---| 'f24' # The F24 key on an American layout.
---| 'lctrl' # The left control key on an American layout.
---| 'lshift' # The left shift key on an American layout.
---| 'lalt' # The left alt / option key on an American layout.
---| 'lgui' # The left GUI (command / windows / super) key on an American layout.
---| 'rctrl' # The right control key on an American layout.
---| 'rshift' # The right shift key on an American layout.
---| 'ralt' # The right alt / option key on an American layout.
---| 'rgui' # The right GUI (command / windows / super) key on an American layout.
---| 'printscreen' # The printscreen key on an American layout.
---| 'scrolllock' # The scroll-lock key on an American layout.
---| 'pause' # The pause key on an American layout.
---| 'insert' # The insert key on an American layout.
---| 'home' # The home key on an American layout.
---| 'numlock' # The numlock / clear key on an American layout.
---| 'pageup' # The page-up key on an American layout.
---| 'delete' # The forward-delete key on an American layout.
---| 'end' # The end key on an American layout.
---| 'pagedown' # The page-down key on an American layout.
---| 'right' # The right-arrow key on an American layout.
---| 'left' # The left-arrow key on an American layout.
---| 'down' # The down-arrow key on an American layout.
---| 'up' # The up-arrow key on an American layout.
---| 'nonusbackslash' # The non-U.S. backslash scancode.
---| 'application' # The application key on an American layout. Windows contextual menu,...
---| 'execute' # The 'execute' key on an American layout.
---| 'help' # The 'help' key on an American layout.
---| 'menu' # The 'menu' key on an American layout.
---| 'select' # The 'select' key on an American layout.
---| 'stop' # The 'stop' key on an American layout.
---| 'again' # The 'again' key on an American layout.
---| 'undo' # The 'undo' key on an American layout.
---| 'cut' # The 'cut' key on an American layout.
---| 'copy' # The 'copy' key on an American layout.
---| 'paste' # The 'paste' key on an American layout.
---| 'find' # The 'find' key on an American layout.
---| 'kp/' # The keypad forward-slash key on an American layout.
---| 'kp*' # The keypad '*' key on an American layout.
---| 'kp-' # The keypad minus key on an American layout.
---| 'kp+' # The keypad plus key on an American layout.
---| 'kp=' # The keypad equals key on an American layout.
---| 'kpenter' # The keypad enter key on an American layout.
---| 'kp1' # The keypad '1' key on an American layout.
---| 'kp2' # The keypad '2' key on an American layout.
---| 'kp3' # The keypad '3' key on an American layout.
---| 'kp4' # The keypad '4' key on an American layout.
---| 'kp5' # The keypad '5' key on an American layout.
---| 'kp6' # The keypad '6' key on an American layout.
---| 'kp7' # The keypad '7' key on an American layout.
---| 'kp8' # The keypad '8' key on an American layout.
---| 'kp9' # The keypad '9' key on an American layout.
---| 'kp0' # The keypad '0' key on an American layout.
---| 'kp.' # The keypad period key on an American layout.
---| 'international1' # The 1st international key on an American layout. Used on Asian keyb...
---| 'international2' # The 2nd international key on an American layout.
---| 'international3' # The 3rd international key on an American layout. Yen.
---| 'international4' # The 4th international key on an American layout.
---| 'international5' # The 5th international key on an American layout.
---| 'international6' # The 6th international key on an American layout.
---| 'international7' # The 7th international key on an American layout.
---| 'international8' # The 8th international key on an American layout.
---| 'international9' # The 9th international key on an American layout.
---| 'lang1' # Hangul/English toggle scancode.
---| 'lang2' # Hanja conversion scancode.
---| 'lang3' # Katakana scancode.
---| 'lang4' # Hiragana scancode.
---| 'lang5' # Zenkaku/Hankaku scancode.
---| 'mute' # The mute key on an American layout.
---| 'volumeup' # The volume up key on an American layout.
---| 'volumedown' # The volume down key on an American layout.
---| 'audionext' # The audio next track key on an American layout.
---| 'audioprev' # The audio previous track key on an American layout.
---| 'audiostop' # The audio stop key on an American layout.
---| 'audioplay' # The audio play key on an American layout.
---| 'audiomute' # The audio mute key on an American layout.
---| 'mediaselect' # The media select key on an American layout.
---| 'www' # The 'WWW' key on an American layout.
---| 'mail' # The Mail key on an American layout.
---| 'calculator' # The calculator key on an American layout.
---| 'computer' # The 'computer' key on an American layout.
---| 'acsearch' # The AC Search key on an American layout.
---| 'achome' # The AC Home key on an American layout.
---| 'acback' # The AC Back key on an American layout.
---| 'acforward' # The AC Forward key on an American layout.
---| 'acstop' # Th AC Stop key on an American layout.
---| 'acrefresh' # The AC Refresh key on an American layout.
---| 'acbookmarks' # The AC Bookmarks key on an American layout.
---| 'power' # The system power scancode.
---| 'brightnessdown' # The brightness-down scancode.
---| 'brightnessup' # The brightness-up scancode.
---| 'displayswitch' # The display switch scancode.
---| 'kbdillumtoggle' # The keyboard illumination toggle scancode.
---| 'kbdillumdown' # The keyboard illumination down scancode.
---| 'kbdillumup' # The keyboard illumination up scancode.
---| 'eject' # The eject scancode.
---| 'sleep' # The system sleep scancode.
---| 'alterase' # The alt-erase key on an American layout.
---| 'sysreq' # The sysreq key on an American layout.
---| 'cancel' # The 'cancel' key on an American layout.
---| 'clear' # The 'clear' key on an American layout.
---| 'prior' # The 'prior' key on an American layout.
---| 'return2' # The 'return2' key on an American layout.
---| 'separator' # The 'separator' key on an American layout.
---| 'out' # The 'out' key on an American layout.
---| 'oper' # The 'oper' key on an American layout.
---| 'clearagain' # The 'clearagain' key on an American layout.
---| 'crsel' # The 'crsel' key on an American layout.
---| 'exsel' # The 'exsel' key on an American layout.
---| 'kp00' # The keypad 00 key on an American layout.
---| 'kp000' # The keypad 000 key on an American layout.
---| 'thsousandsseparator' # The thousands-separator key on an American layout.
---| 'decimalseparator' # The decimal separator key on an American layout.
---| 'currencyunit' # The currency unit key on an American layout.
---| 'currencysubunit' # The currency sub-unit key on an American layout.
---| 'app1' # The 'app1' scancode.
---| 'app2' # The 'app2' scancode.
---| 'unknown' # An unknown key.

--- Gets the key corresponding to the given hardware scancode. Unlike key constants, Scancodes are ke...
---@param scancode LoveKeyboardScancode
--- The scancode to get the key from.
---@return LoveKeyboardKeyConstant
--- The key corresponding to the given scancode, or 'unknown' if the scancode doe...
function love.keyboard.getKeyFromScancode(scancode) end

--- Gets the hardware scancode corresponding to the given key. Unlike key constants, Scancodes are ke...
---@param key LoveKeyboardKeyConstant
--- The key to get the scancode from.
---@return LoveKeyboardScancode
--- The scancode corresponding to the given key, or 'unknown' if the given key ha...
function love.keyboard.getScancodeFromKey(key) end

--- Gets whether key repeat is enabled.
---@return boolean
--- Whether key repeat is enabled.
function love.keyboard.hasKeyRepeat() end

--- Gets whether screen keyboard is supported.
---@return boolean
--- Whether screen keyboard is supported.
function love.keyboard.hasScreenKeyboard() end

--- Gets whether text input events are enabled.
---@return boolean
--- Whether text input events are enabled.
function love.keyboard.hasTextInput() end

--- Checks whether a certain key is down. Not to be confused with love.keypressed or love.keyreleased.
---@param key LoveKeyboardKeyConstant
--- A key to check.
---@param ___ LoveKeyboardKeyConstant
--- Additional keys to check.
---@overload fun(LoveKeyboardKeyConstant)
---@return boolean
--- True if any supplied key is down, false if not.
function love.keyboard.isDown(key, ___) end

--- Checks whether the specified Scancodes are pressed. Not to be confused with love.keypressed or lo...
---@param scancode LoveKeyboardScancode
--- A Scancode to check.
---@param ___ LoveKeyboardScancode
--- Additional Scancodes to check.
---@return boolean
--- True if any supplied Scancode is down, false if not.
function love.keyboard.isScancodeDown(scancode, ___) end

--- Enables or disables key repeat for love.keypressed. It is disabled by default.
---@param enable boolean
--- Whether repeat keypress events should be enabled when a key is held down.
function love.keyboard.setKeyRepeat(enable) end

--- Enables or disables text input events. It is enabled by default on Windows, Mac, and Linux, and d...
---@param enable boolean
--- Whether text input events should be enabled.
---@param x number
--- Text rectangle x position.
---@param y number
--- Text rectangle y position.
---@param w number
--- Text rectangle width.
---@param h number
--- Text rectangle height.
---@overload fun(boolean)
function love.keyboard.setTextInput(enable, x, y, w, h) end

--- ------------------------------------------------------------
--- love.math
--- Provides system-independent mathematical functions.
---@class love.math
love.math = {}

--- The layout of matrix elements (row-major or column-major).
---@alias LoveMathMatrixLayout
---| 'row' # The matrix is row-major:
---| 'column' # The matrix is column-major:

--- A Bézier curve object that can evaluate and render Bézier curves of arbitrary degree. For more ...
---@class LoveMathBezierCurve
LoveMathBezierCurve = {}

--- Evaluate Bézier curve at parameter t. The parameter must be between 0 and 1 (inclusive). This fu...
---@param t number
--- Where to evaluate the curve.
---@return number
--- x coordinate of the curve at parameter t.
---@return number
--- y coordinate of the curve at parameter t.
function LoveMathBezierCurve:evaluate(t) end

--- Get coordinates of the i-th control point. Indices start with 1.
---@param i number
--- Index of the control point.
---@return number
--- Position of the control point along the x axis.
---@return number
--- Position of the control point along the y axis.
function LoveMathBezierCurve:getControlPoint(i) end

--- Get the number of control points in the Bézier curve.
---@return number
--- The number of control points.
function LoveMathBezierCurve:getControlPointCount() end

--- Get degree of the Bézier curve. The degree is equal to number-of-control-points - 1.
---@return number
--- Degree of the Bézier curve.
function LoveMathBezierCurve:getDegree() end

--- Get the derivative of the Bézier curve. This function can be used to rotate sprites moving along...
---@return LoveMathBezierCurve
--- The derivative curve.
function LoveMathBezierCurve:getDerivative() end

--- Gets a BezierCurve that corresponds to the specified segment of this BezierCurve.
---@param startpoint number
--- The starting point along the curve. Must be between 0 and 1.
---@param endpoint number
--- The end of the segment. Must be between 0 and 1.
---@return LoveMathBezierCurve
--- A BezierCurve that corresponds to the specified segment.
function LoveMathBezierCurve:getSegment(startpoint, endpoint) end

--- Insert control point as the new i-th control point. Existing control points from i onwards are pu...
---@param x number
--- Position of the control point along the x axis.
---@param y number
--- Position of the control point along the y axis.
---@param i? number
--- Index of the control point.
function LoveMathBezierCurve:insertControlPoint(x, y, i) end

--- Removes the specified control point.
---@param index number
--- The index of the control point to remove.
function LoveMathBezierCurve:removeControlPoint(index) end

--- Get a list of coordinates to be used with love.graphics.line. This function samples the Bézier c...
---@param depth? number
--- Number of recursive subdivision steps.
---@return table
--- List of x,y-coordinate pairs of points on the curve.
function LoveMathBezierCurve:render(depth) end

--- Get a list of coordinates on a specific part of the curve, to be used with love.graphics.line. Th...
---@param startpoint number
--- The starting point along the curve. Must be between 0 and 1.
---@param endpoint number
--- The end of the segment to render. Must be between 0 and 1.
---@param depth? number
--- Number of recursive subdivision steps.
---@return table
--- List of x,y-coordinate pairs of points on the specified part of the curve.
function LoveMathBezierCurve:renderSegment(startpoint, endpoint, depth) end

--- Rotate the Bézier curve by an angle.
---@param angle number
--- Rotation angle in radians.
---@param ox? number
--- X coordinate of the rotation center.
---@param oy? number
--- Y coordinate of the rotation center.
function LoveMathBezierCurve:rotate(angle, ox, oy) end

--- Scale the Bézier curve by a factor.
---@param s number
--- Scale factor.
---@param ox? number
--- X coordinate of the scaling center.
---@param oy? number
--- Y coordinate of the scaling center.
function LoveMathBezierCurve:scale(s, ox, oy) end

--- Set coordinates of the i-th control point. Indices start with 1.
---@param i number
--- Index of the control point.
---@param x number
--- Position of the control point along the x axis.
---@param y number
--- Position of the control point along the y axis.
function LoveMathBezierCurve:setControlPoint(i, x, y) end

--- Move the Bézier curve by an offset.
---@param dx number
--- Offset along the x axis.
---@param dy number
--- Offset along the y axis.
function LoveMathBezierCurve:translate(dx, dy) end

--- A random number generation object which has its own random state.
---@class LoveMathRandomGenerator
LoveMathRandomGenerator = {}

--- Gets the seed of the random number generator object. The seed is split into two numbers due to Lu...
---@return number
--- Integer number representing the lower 32 bits of the RandomGenerator's 64 bit...
---@return number
--- Integer number representing the higher 32 bits of the RandomGenerator's 64 bi...
function LoveMathRandomGenerator:getSeed() end

--- Gets the current state of the random number generator. This returns an opaque string which is onl...
---@return string
--- The current state of the RandomGenerator object, represented as a string.
function LoveMathRandomGenerator:getState() end

--- Generates a pseudo-random number in a platform independent manner.
---@param min number
--- The minimum possible value it should return.
---@param max number
--- The maximum possible value it should return.
---@overload fun()
---@overload fun(number)
---@return number
--- The pseudo-random integer number.
function LoveMathRandomGenerator:random(min, max) end

--- Get a normally distributed pseudo random number.
---@param stddev? number
--- Standard deviation of the distribution.
---@param mean? number
--- The mean of the distribution.
---@return number
--- Normally distributed random number with variance (stddev)² and the specified...
function LoveMathRandomGenerator:randomNormal(stddev, mean) end

--- Sets the seed of the random number generator using the specified integer number.
---@param low number
--- The lower 32 bits of the seed value. Must be within the range of 2^32 - 1.
---@param high number
--- The higher 32 bits of the seed value. Must be within the range of 2^32 - 1.
---@overload fun(number)
function LoveMathRandomGenerator:setSeed(low, high) end

--- Sets the current state of the random number generator. The value used as an argument for this fun...
---@param state string
--- The new state of the RandomGenerator object, represented as a string. This sh...
function LoveMathRandomGenerator:setState(state) end

--- Object containing a coordinate system transformation. The love.graphics module has several functi...
---@class LoveMathTransform
LoveMathTransform = {}

--- Applies the given other Transform object to this one. This effectively multiplies this Transform'...
---@param other LoveMathTransform
--- The other Transform object to apply to this Transform.
---@return LoveMathTransform
--- The Transform object the method was called on. Allows easily chaining Transfo...
function LoveMathTransform:apply(other) end

--- Creates a new copy of this Transform.
---@return LoveMathTransform
--- The copy of this Transform.
function LoveMathTransform:clone() end

--- Gets the internal 4x4 transformation matrix stored by this Transform. The matrix is returned in r...
---@return number
--- The first column of the first row of the matrix.
---@return number
--- The second column of the first row of the matrix.
---@return number
--- The third column of the first row of the matrix.
---@return number
--- The fourth column of the first row of the matrix.
---@return number
--- The first column of the second row of the matrix.
---@return number
--- The second column of the second row of the matrix.
---@return number
--- The third column of the second row of the matrix.
---@return number
--- The fourth column of the second row of the matrix.
---@return number
--- The first column of the third row of the matrix.
---@return number
--- The second column of the third row of the matrix.
---@return number
--- The third column of the third row of the matrix.
---@return number
--- The fourth column of the third row of the matrix.
---@return number
--- The first column of the fourth row of the matrix.
---@return number
--- The second column of the fourth row of the matrix.
---@return number
--- The third column of the fourth row of the matrix.
---@return number
--- The fourth column of the fourth row of the matrix.
function LoveMathTransform:getMatrix() end

--- Creates a new Transform containing the inverse of this Transform.
---@return LoveMathTransform
--- A new Transform object representing the inverse of this Transform's matrix.
function LoveMathTransform:inverse() end

--- Applies the reverse of the Transform object's transformation to the given 2D position. This effec...
---@param localX number
--- The x component of the position with the transform applied.
---@param localY number
--- The y component of the position with the transform applied.
---@return number
--- The x component of the position in global coordinates.
---@return number
--- The y component of the position in global coordinates.
function LoveMathTransform:inverseTransformPoint(localX, localY) end

--- Checks whether the Transform is an affine transformation.
---@return boolean
--- true if the transform object is an affine transformation, false otherwise.
function LoveMathTransform:isAffine2DTransform() end

--- Resets the Transform to an identity state. All previously applied transformations are erased.
---@return LoveMathTransform
--- The Transform object the method was called on. Allows easily chaining Transfo...
function LoveMathTransform:reset() end

--- Applies a rotation to the Transform's coordinate system. This method does not reset any previousl...
---@param angle number
--- The relative angle in radians to rotate this Transform by.
---@return LoveMathTransform
--- The Transform object the method was called on. Allows easily chaining Transfo...
function LoveMathTransform:rotate(angle) end

--- Scales the Transform's coordinate system. This method does not reset any previously applied trans...
---@param sx number
--- The relative scale factor along the x-axis.
---@param sy? number
--- The relative scale factor along the y-axis.
---@return LoveMathTransform
--- The Transform object the method was called on. Allows easily chaining Transfo...
function LoveMathTransform:scale(sx, sy) end

--- Directly sets the Transform's internal 4x4 transformation matrix.
---@param layout LoveMathMatrixLayout
--- How to interpret the matrix element arguments (row-major or column-major).
---@param e1_1 number
--- The first column of the first row of the matrix.
---@param e1_2 number
--- The second column of the first row or the first column of the second row of t...
---@param e1_3 number
--- The third column/row of the first row/column of the matrix.
---@param e1_4 number
--- The fourth column/row of the first row/column of the matrix.
---@param e2_1 number
--- The first column/row of the second row/column of the matrix.
---@param e2_2 number
--- The second column/row of the second row/column of the matrix.
---@param e2_3 number
--- The third column/row of the second row/column of the matrix.
---@param e2_4 number
--- The fourth column/row of the second row/column of the matrix.
---@param e3_1 number
--- The first column/row of the third row/column of the matrix.
---@param e3_2 number
--- The second column/row of the third row/column of the matrix.
---@param e3_3 number
--- The third column/row of the third row/column of the matrix.
---@param e3_4 number
--- The fourth column/row of the third row/column of the matrix.
---@param e4_1 number
--- The first column/row of the fourth row/column of the matrix.
---@param e4_2 number
--- The second column/row of the fourth row/column of the matrix.
---@param e4_3 number
--- The third column/row of the fourth row/column of the matrix.
---@param e4_4 number
--- The fourth column of the fourth row of the matrix.
---@overload fun(number, number, number, number, number, number, number, number, number, number, number,...)
---@overload fun(LoveMathMatrixLayout, table)
---@return LoveMathTransform
--- The Transform object the method was called on. Allows easily chaining Transfo...
function LoveMathTransform:setMatrix(
    layout,
    e1_1,
    e1_2,
    e1_3,
    e1_4,
    e2_1,
    e2_2,
    e2_3,
    e2_4,
    e3_1,
    e3_2,
    e3_3,
    e3_4,
    e4_1,
    e4_2,
    e4_3,
    e4_4
)
end

--- Resets the Transform to the specified transformation parameters.
---@param x number
--- The position of the Transform on the x-axis.
---@param y number
--- The position of the Transform on the y-axis.
---@param angle? number
--- The orientation of the Transform in radians.
---@param sx? number
--- Scale factor on the x-axis.
---@param sy? number
--- Scale factor on the y-axis.
---@param ox? number
--- Origin offset on the x-axis.
---@param oy? number
--- Origin offset on the y-axis.
---@param kx? number
--- Shearing / skew factor on the x-axis.
---@param ky? number
--- Shearing / skew factor on the y-axis.
---@return LoveMathTransform
--- The Transform object the method was called on. Allows easily chaining Transfo...
function LoveMathTransform:setTransformation(x, y, angle, sx, sy, ox, oy, kx, ky) end

--- Applies a shear factor (skew) to the Transform's coordinate system. This method does not reset an...
---@param kx number
--- The shear factor along the x-axis.
---@param ky number
--- The shear factor along the y-axis.
---@return LoveMathTransform
--- The Transform object the method was called on. Allows easily chaining Transfo...
function LoveMathTransform:shear(kx, ky) end

--- Applies the Transform object's transformation to the given 2D position. This effectively converts...
---@param globalX number
--- The x component of the position in global coordinates.
---@param globalY number
--- The y component of the position in global coordinates.
---@return number
--- The x component of the position with the transform applied.
---@return number
--- The y component of the position with the transform applied.
function LoveMathTransform:transformPoint(globalX, globalY) end

--- Applies a translation to the Transform's coordinate system. This method does not reset any previo...
---@param dx number
--- The relative translation along the x-axis.
---@param dy number
--- The relative translation along the y-axis.
---@return LoveMathTransform
--- The Transform object the method was called on. Allows easily chaining Transfo...
function LoveMathTransform:translate(dx, dy) end

--- Converts a color from 0..255 to 0..1 range.
---@param rb number
--- Red color component in 0..255 range.
---@param gb number
--- Green color component in 0..255 range.
---@param bb number
--- Blue color component in 0..255 range.
---@param ab? number
--- Alpha color component in 0..255 range.
---@return number
--- Red color component in 0..1 range.
---@return number
--- Green color component in 0..1 range.
---@return number
--- Blue color component in 0..1 range.
---@return number
--- Alpha color component in 0..1 range or nil if alpha is not specified.
function love.math.colorFromBytes(rb, gb, bb, ab) end

--- Converts a color from 0..1 to 0..255 range.
---@param r number
--- Red color component.
---@param g number
--- Green color component.
---@param b number
--- Blue color component.
---@param a? number
--- Alpha color component.
---@return number
--- Red color component in 0..255 range.
---@return number
--- Green color component in 0..255 range.
---@return number
--- Blue color component in 0..255 range.
---@return number
--- Alpha color component in 0..255 range or nil if alpha is not specified.
function love.math.colorToBytes(r, g, b, a) end

--- Converts a color from gamma-space (sRGB) to linear-space (RGB). This is useful when doing gamma-c...
---@param r number
--- The red channel of the sRGB color to convert.
---@param g number
--- The green channel of the sRGB color to convert.
---@param b number
--- The blue channel of the sRGB color to convert.
---@overload fun(table)
---@return number
--- The red channel of the converted color in linear RGB space.
---@return number
--- The green channel of the converted color in linear RGB space.
---@return number
--- The blue channel of the converted color in linear RGB space.
function love.math.gammaToLinear(r, g, b) end

--- Gets the seed of the random number generator. The seed is split into two numbers due to Lua's use...
---@return number
--- Integer number representing the lower 32 bits of the random number generator'...
---@return number
--- Integer number representing the higher 32 bits of the random number generator...
function love.math.getRandomSeed() end

--- Gets the current state of the random number generator. This returns an opaque implementation-depe...
---@return string
--- The current state of the random number generator, represented as a string.
function love.math.getRandomState() end

--- Checks whether a polygon is convex. PolygonShapes in love.physics, some forms of Meshes, and poly...
---@param x1 number
--- The position of the first vertex of the polygon on the x-axis.
---@param y1 number
--- The position of the first vertex of the polygon on the y-axis.
---@param x2 number
--- The position of the second vertex of the polygon on the x-axis.
---@param y2 number
--- The position of the second vertex of the polygon on the y-axis.
---@param ___ number
--- Additional position of the vertex of the polygon on the x-axis and y-axis.
---@overload fun(table)
---@return boolean
--- Whether the given polygon is convex.
function love.math.isConvex(x1, y1, x2, y2, ___) end

--- Converts a color from linear-space (RGB) to gamma-space (sRGB). This is useful when storing linea...
---@param lr number
--- The red channel of the linear RGB color to convert.
---@param lg number
--- The green channel of the linear RGB color to convert.
---@param lb number
--- The blue channel of the linear RGB color to convert.
---@overload fun(table)
---@return number
--- The red channel of the converted color in gamma sRGB space.
---@return number
--- The green channel of the converted color in gamma sRGB space.
---@return number
--- The blue channel of the converted color in gamma sRGB space.
function love.math.linearToGamma(lr, lg, lb) end

--- Creates a new BezierCurve object. The number of vertices in the control polygon determines the de...
---@param x1 number
--- The position of the first vertex of the control polygon on the x-axis.
---@param y1 number
--- The position of the first vertex of the control polygon on the y-axis.
---@param x2 number
--- The position of the second vertex of the control polygon on the x-axis.
---@param y2 number
--- The position of the second vertex of the control polygon on the y-axis.
---@param ___ number
--- Additional position of the vertex of the control polygon on the x-axis and y-...
---@overload fun(table)
---@return LoveMathBezierCurve
--- A Bézier curve object.
function love.math.newBezierCurve(x1, y1, x2, y2, ___) end

--- Creates a new RandomGenerator object which is completely independent of other RandomGenerator obj...
---@param low number
--- The lower 32 bits of the seed number to use for this object.
---@param high number
--- The higher 32 bits of the seed number to use for this object.
---@overload fun()
---@overload fun(number)
---@return LoveMathRandomGenerator
--- The new Random Number Generator object.
function love.math.newRandomGenerator(low, high) end

--- Creates a new Transform object.
---@param x number
--- The position of the new Transform on the x-axis.
---@param y number
--- The position of the new Transform on the y-axis.
---@param angle? number
--- The orientation of the new Transform in radians.
---@param sx? number
--- Scale factor on the x-axis.
---@param sy? number
--- Scale factor on the y-axis.
---@param ox? number
--- Origin offset on the x-axis.
---@param oy? number
--- Origin offset on the y-axis.
---@param kx? number
--- Shearing / skew factor on the x-axis.
---@param ky? number
--- Shearing / skew factor on the y-axis.
---@overload fun()
---@return LoveMathTransform
--- The new Transform object.
function love.math.newTransform(x, y, angle, sx, sy, ox, oy, kx, ky) end

--- Generates a Simplex or Perlin noise value in 1-4 dimensions. The return value will always be the ...
---@param x number
--- The first value of the 4-dimensional vector used to generate the noise value.
---@param y number
--- The second value of the 4-dimensional vector used to generate the noise value.
---@param z number
--- The third value of the 4-dimensional vector used to generate the noise value.
---@param w number
--- The fourth value of the 4-dimensional vector used to generate the noise value.
---@overload fun(number)
---@overload fun(number, number)
---@overload fun(number, number, number)
---@return number
--- The noise value in the range of 1.
function love.math.noise(x, y, z, w) end

--- Generates a pseudo-random number in a platform independent manner. The default love.run seeds thi...
---@param min number
--- The minimum possible value it should return.
---@param max number
--- The maximum possible value it should return.
---@overload fun()
---@overload fun(number)
---@return number
--- The pseudo-random integer number.
function love.math.random(min, max) end

--- Get a normally distributed pseudo random number.
---@param stddev? number
--- Standard deviation of the distribution.
---@param mean? number
--- The mean of the distribution.
---@return number
--- Normally distributed random number with variance (stddev)² and the specified...
function love.math.randomNormal(stddev, mean) end

--- Sets the seed of the random number generator using the specified integer number. This is called i...
---@param low number
--- The lower 32 bits of the seed value. Must be within the range of 2^32 - 1.
---@param high number
--- The higher 32 bits of the seed value. Must be within the range of 2^32 - 1.
---@overload fun(number)
function love.math.setRandomSeed(low, high) end

--- Sets the current state of the random number generator. The value used as an argument for this fun...
---@param state string
--- The new state of the random number generator, represented as a string. This s...
function love.math.setRandomState(state) end

--- Decomposes a simple convex or concave polygon into triangles.
---@param x1 number
--- The position of the first vertex of the polygon on the x-axis.
---@param y1 number
--- The position of the first vertex of the polygon on the y-axis.
---@param x2 number
--- The position of the second vertex of the polygon on the x-axis.
---@param y2 number
--- The position of the second vertex of the polygon on the y-axis.
---@param x3 number
--- The position of the third vertex of the polygon on the x-axis.
---@param y3 number
--- The position of the third vertex of the polygon on the y-axis.
---@overload fun(table)
---@return table
--- List of triangles the polygon is composed of, in the form of {{x1, y1, x2, y2...
function love.math.triangulate(x1, y1, x2, y2, x3, y3) end

--- ------------------------------------------------------------
--- love.mouse
--- Provides an interface to the user's mouse.
---@class love.mouse
love.mouse = {}

--- Types of hardware cursors.
---@alias LoveMouseCursorType
---| 'image' # The cursor is using a custom image.
---| 'arrow' # An arrow pointer.
---| 'ibeam' # An I-beam, normally used when mousing over editable or selectable t...
---| 'wait' # Wait graphic.
---| 'waitarrow' # Small wait cursor with an arrow pointer.
---| 'crosshair' # Crosshair symbol.
---| 'sizenwse' # Double arrow pointing to the top-left and bottom-right.
---| 'sizenesw' # Double arrow pointing to the top-right and bottom-left.
---| 'sizewe' # Double arrow pointing left and right.
---| 'sizens' # Double arrow pointing up and down.
---| 'sizeall' # Four-pointed arrow pointing up, down, left, and right.
---| 'no' # Slashed circle or crossbones.
---| 'hand' # Hand symbol.

--- Represents a hardware cursor.
---@class LoveMouseCursor
LoveMouseCursor = {}

--- Gets the type of the Cursor.
---@return LoveMouseCursorType
--- The type of the Cursor.
function LoveMouseCursor:getType() end

--- Gets the current Cursor.
---@return LoveMouseCursor
--- The current cursor, or nil if no cursor is set.
function love.mouse.getCursor() end

--- Returns the current position of the mouse.
---@return number
--- The position of the mouse along the x-axis.
---@return number
--- The position of the mouse along the y-axis.
function love.mouse.getPosition() end

--- Gets whether relative mode is enabled for the mouse. If relative mode is enabled, the cursor is h...
---@return boolean
--- True if relative mode is enabled, false if it's disabled.
function love.mouse.getRelativeMode() end

--- Gets a Cursor object representing a system-native hardware cursor. Hardware cursors are framerate...
---@param ctype LoveMouseCursorType
--- The type of system cursor to get.
---@return LoveMouseCursor
--- The Cursor object representing the system cursor type.
function love.mouse.getSystemCursor(ctype) end

--- Returns the current x-position of the mouse.
---@return number
--- The position of the mouse along the x-axis.
function love.mouse.getX() end

--- Returns the current y-position of the mouse.
---@return number
--- The position of the mouse along the y-axis.
function love.mouse.getY() end

--- Gets whether cursor functionality is supported. If it isn't supported, calling love.mouse.newCurs...
---@return boolean
--- Whether the system has cursor functionality.
function love.mouse.isCursorSupported() end

--- Checks whether a certain mouse button is down. This function does not detect mouse wheel scrollin...
---@param button number
--- The index of a button to check. 1 is the primary mouse button, 2 is the secon...
---@param ___ number
--- Additional button numbers to check.
---@return boolean
--- True if any specified button is down.
function love.mouse.isDown(button, ___) end

--- Checks if the mouse is grabbed.
---@return boolean
--- True if the cursor is grabbed, false if it is not.
function love.mouse.isGrabbed() end

--- Checks if the cursor is visible.
---@return boolean
--- True if the cursor to visible, false if the cursor is hidden.
function love.mouse.isVisible() end

--- Creates a new hardware Cursor object from an image file or ImageData. Hardware cursors are framer...
---@param imageData LoveImageImageData
--- The ImageData to use for the new Cursor.
---@param hotx? number
--- The x-coordinate in the ImageData of the cursor's hot spot.
---@param hoty? number
--- The y-coordinate in the ImageData of the cursor's hot spot.
---@return LoveMouseCursor
--- The new Cursor object.
function love.mouse.newCursor(imageData, hotx, hoty) end

--- Sets the current mouse cursor.
---@param cursor LoveMouseCursor
--- The Cursor object to use as the current mouse cursor.
---@overload fun()
function love.mouse.setCursor(cursor) end

--- Grabs the mouse and confines it to the window.
---@param grab boolean
--- True to confine the mouse, false to let it leave the window.
function love.mouse.setGrabbed(grab) end

--- Sets the current position of the mouse. Non-integer values are floored.
---@param x number
--- The new position of the mouse along the x-axis.
---@param y number
--- The new position of the mouse along the y-axis.
function love.mouse.setPosition(x, y) end

--- Sets whether relative mode is enabled for the mouse. When relative mode is enabled, the cursor is...
---@param enable boolean
--- True to enable relative mode, false to disable it.
function love.mouse.setRelativeMode(enable) end

--- Sets the current visibility of the cursor.
---@param visible boolean
--- True to set the cursor to visible, false to hide the cursor.
function love.mouse.setVisible(visible) end

--- Sets the current X position of the mouse. Non-integer values are floored.
---@param x number
--- The new position of the mouse along the x-axis.
function love.mouse.setX(x) end

--- Sets the current Y position of the mouse. Non-integer values are floored.
---@param y number
--- The new position of the mouse along the y-axis.
function love.mouse.setY(y) end

--- ------------------------------------------------------------
--- love.physics
--- Can simulate 2D rigid body physics in a realistic manner. This module is based on Box2D, and this...
---@class love.physics
love.physics = {}

--- The types of a Body.
---@alias LovePhysicsBodyType
---| 'static' # Static bodies do not move.
---| 'dynamic' # Dynamic bodies collide with all bodies.
---| 'kinematic' # Kinematic bodies only collide with dynamic bodies.

--- Different types of joints.
---@alias LovePhysicsJointType
---| 'distance' # A DistanceJoint.
---| 'friction' # A FrictionJoint.
---| 'gear' # A GearJoint.
---| 'mouse' # A MouseJoint.
---| 'prismatic' # A PrismaticJoint.
---| 'pulley' # A PulleyJoint.
---| 'revolute' # A RevoluteJoint.
---| 'rope' # A RopeJoint.
---| 'weld' # A WeldJoint.

--- The different types of Shapes, as returned by Shape:getType.
---@alias LovePhysicsShapeType
---| 'circle' # The Shape is a CircleShape.
---| 'polygon' # The Shape is a PolygonShape.
---| 'edge' # The Shape is a EdgeShape.
---| 'chain' # The Shape is a ChainShape.

--- Bodies are objects with velocity and position.
---@class LovePhysicsBody
LovePhysicsBody = {}

--- Applies an angular impulse to a body. This makes a single, instantaneous addition to the body mom...
---@param impulse number
--- The impulse in kilogram-square meter per second.
function LovePhysicsBody:applyAngularImpulse(impulse) end

--- Apply force to a Body. A force pushes a body in a direction. A body with with a larger mass will ...
---@param fx number
--- The x component of force to apply.
---@param fy number
--- The y component of force to apply.
---@param x number
--- The x position to apply the force.
---@param y number
--- The y position to apply the force.
---@overload fun(number, number)
function LovePhysicsBody:applyForce(fx, fy, x, y) end

--- Applies an impulse to a body. This makes a single, instantaneous addition to the body momentum. A...
---@param ix number
--- The x component of the impulse.
---@param iy number
--- The y component of the impulse.
---@param x number
--- The x position to apply the impulse.
---@param y number
--- The y position to apply the impulse.
---@overload fun(number, number)
function LovePhysicsBody:applyLinearImpulse(ix, iy, x, y) end

--- Apply torque to a body. Torque is like a force that will change the angular velocity (spin) of a ...
---@param torque number
--- The torque to apply.
function LovePhysicsBody:applyTorque(torque) end

--- Explicitly destroys the Body and all fixtures and joints attached to it. An error will occur if y...
function LovePhysicsBody:destroy() end

--- Get the angle of the body. The angle is measured in radians. If you need to transform it to degre...
---@return number
--- The angle in radians.
function LovePhysicsBody:getAngle() end

--- Gets the Angular damping of the Body The angular damping is the ''rate of decrease of the angular...
---@return number
--- The value of the angular damping.
function LovePhysicsBody:getAngularDamping() end

--- Get the angular velocity of the Body. The angular velocity is the ''rate of change of angle over ...
---@return number
--- The angular velocity in radians/second.
function LovePhysicsBody:getAngularVelocity() end

--- Gets a list of all Contacts attached to the Body.
---@return table
--- A list with all contacts associated with the Body.
function LovePhysicsBody:getContacts() end

--- Returns a table with all fixtures.
---@return table
--- A sequence with all fixtures.
function LovePhysicsBody:getFixtures() end

--- Returns the gravity scale factor.
---@return number
--- The gravity scale factor.
function LovePhysicsBody:getGravityScale() end

--- Gets the rotational inertia of the body. The rotational inertia is how hard is it to make the bod...
---@return number
--- The rotational inertial of the body.
function LovePhysicsBody:getInertia() end

--- Returns a table containing the Joints attached to this Body.
---@return table
--- A sequence with the Joints attached to the Body.
function LovePhysicsBody:getJoints() end

--- Gets the linear damping of the Body. The linear damping is the ''rate of decrease of the linear v...
---@return number
--- The value of the linear damping.
function LovePhysicsBody:getLinearDamping() end

--- Gets the linear velocity of the Body from its center of mass. The linear velocity is the ''rate o...
---@return number
--- The x-component of the velocity vector
---@return number
--- The y-component of the velocity vector
function LovePhysicsBody:getLinearVelocity() end

--- Get the linear velocity of a point on the body. The linear velocity for a point on the body is th...
---@param x number
--- The x position to measure velocity.
---@param y number
--- The y position to measure velocity.
---@return number
--- The x component of velocity at point (x,y).
---@return number
--- The y component of velocity at point (x,y).
function LovePhysicsBody:getLinearVelocityFromLocalPoint(x, y) end

--- Get the linear velocity of a point on the body. The linear velocity for a point on the body is th...
---@param x number
--- The x position to measure velocity.
---@param y number
--- The y position to measure velocity.
---@return number
--- The x component of velocity at point (x,y).
---@return number
--- The y component of velocity at point (x,y).
function LovePhysicsBody:getLinearVelocityFromWorldPoint(x, y) end

--- Get the center of mass position in local coordinates. Use Body:getWorldCenter to get the center o...
---@return number
--- The x coordinate of the center of mass.
---@return number
--- The y coordinate of the center of mass.
function LovePhysicsBody:getLocalCenter() end

--- Transform a point from world coordinates to local coordinates.
---@param worldX number
--- The x position in world coordinates.
---@param worldY number
--- The y position in world coordinates.
---@return number
--- The x position in local coordinates.
---@return number
--- The y position in local coordinates.
function LovePhysicsBody:getLocalPoint(worldX, worldY) end

--- Transforms multiple points from world coordinates to local coordinates.
---@param x1 number
--- (Argument) The x position of the first point.
---@param y1 number
--- (Argument) The y position of the first point.
---@param x2 number
--- (Argument) The x position of the second point.
---@param y2 number
--- (Argument) The y position of the second point.
---@param ___ number
--- (Argument) You can continue passing x and y position of the points.
---@return number
--- (Result) The transformed x position of the first point.
---@return number
--- (Result) The transformed y position of the first point.
---@return number
--- (Result) The transformed x position of the second point.
---@return number
--- (Result) The transformed y position of the second point.
---@return number
--- (Result) Additional transformed x and y position of the points.
function LovePhysicsBody:getLocalPoints(x1, y1, x2, y2, ___) end

--- Transform a vector from world coordinates to local coordinates.
---@param worldX number
--- The vector x component in world coordinates.
---@param worldY number
--- The vector y component in world coordinates.
---@return number
--- The vector x component in local coordinates.
---@return number
--- The vector y component in local coordinates.
function LovePhysicsBody:getLocalVector(worldX, worldY) end

--- Get the mass of the body. Static bodies always have a mass of 0.
---@return number
--- The mass of the body (in kilograms).
function LovePhysicsBody:getMass() end

--- Returns the mass, its center, and the rotational inertia.
---@return number
--- The x position of the center of mass.
---@return number
--- The y position of the center of mass.
---@return number
--- The mass of the body.
---@return number
--- The rotational inertia.
function LovePhysicsBody:getMassData() end

--- Get the position of the body. Note that this may not be the center of mass of the body.
---@return number
--- The x position.
---@return number
--- The y position.
function LovePhysicsBody:getPosition() end

--- Get the position and angle of the body. Note that the position may not be the center of mass of t...
---@return number
--- The x component of the position.
---@return number
--- The y component of the position.
---@return number
--- The angle in radians.
function LovePhysicsBody:getTransform() end

--- Returns the type of the body.
---@return LovePhysicsBodyType
--- The body type.
function LovePhysicsBody:getType() end

--- Returns the Lua value associated with this Body.
---@return any
--- The Lua value associated with the Body.
function LovePhysicsBody:getUserData() end

--- Gets the World the body lives in.
---@return LovePhysicsWorld
--- The world the body lives in.
function LovePhysicsBody:getWorld() end

--- Get the center of mass position in world coordinates. Use Body:getLocalCenter to get the center o...
---@return number
--- The x coordinate of the center of mass.
---@return number
--- The y coordinate of the center of mass.
function LovePhysicsBody:getWorldCenter() end

--- Transform a point from local coordinates to world coordinates.
---@param localX number
--- The x position in local coordinates.
---@param localY number
--- The y position in local coordinates.
---@return number
--- The x position in world coordinates.
---@return number
--- The y position in world coordinates.
function LovePhysicsBody:getWorldPoint(localX, localY) end

--- Transforms multiple points from local coordinates to world coordinates.
---@param x1 number
--- The x position of the first point.
---@param y1 number
--- The y position of the first point.
---@param x2 number
--- The x position of the second point.
---@param y2 number
--- The y position of the second point.
---@return number
--- The transformed x position of the first point.
---@return number
--- The transformed y position of the first point.
---@return number
--- The transformed x position of the second point.
---@return number
--- The transformed y position of the second point.
function LovePhysicsBody:getWorldPoints(x1, y1, x2, y2) end

--- Transform a vector from local coordinates to world coordinates.
---@param localX number
--- The vector x component in local coordinates.
---@param localY number
--- The vector y component in local coordinates.
---@return number
--- The vector x component in world coordinates.
---@return number
--- The vector y component in world coordinates.
function LovePhysicsBody:getWorldVector(localX, localY) end

--- Get the x position of the body in world coordinates.
---@return number
--- The x position in world coordinates.
function LovePhysicsBody:getX() end

--- Get the y position of the body in world coordinates.
---@return number
--- The y position in world coordinates.
function LovePhysicsBody:getY() end

--- Returns whether the body is actively used in the simulation.
---@return boolean
--- True if the body is active or false if not.
function LovePhysicsBody:isActive() end

--- Returns the sleep status of the body.
---@return boolean
--- True if the body is awake or false if not.
function LovePhysicsBody:isAwake() end

--- Get the bullet status of a body. There are two methods to check for body collisions: * at their l...
---@return boolean
--- The bullet status of the body.
function LovePhysicsBody:isBullet() end

--- Gets whether the Body is destroyed. Destroyed bodies cannot be used.
---@return boolean
--- Whether the Body is destroyed.
function LovePhysicsBody:isDestroyed() end

--- Returns whether the body rotation is locked.
---@return boolean
--- True if the body's rotation is locked or false if not.
function LovePhysicsBody:isFixedRotation() end

--- Returns the sleeping behaviour of the body.
---@return boolean
--- True if the body is allowed to sleep or false if not.
function LovePhysicsBody:isSleepingAllowed() end

--- Gets whether the Body is touching the given other Body.
---@param otherbody LovePhysicsBody
--- The other body to check.
---@return boolean
--- True if this body is touching the other body, false otherwise.
function LovePhysicsBody:isTouching(otherbody) end

--- Resets the mass of the body by recalculating it from the mass properties of the fixtures.
function LovePhysicsBody:resetMassData() end

--- Sets whether the body is active in the world. An inactive body does not take part in the simulati...
---@param active boolean
--- If the body is active or not.
function LovePhysicsBody:setActive(active) end

--- Set the angle of the body. The angle is measured in radians. If you need to transform it from deg...
---@param angle number
--- The angle in radians.
function LovePhysicsBody:setAngle(angle) end

--- Sets the angular damping of a Body See Body:getAngularDamping for a definition of angular damping...
---@param damping number
--- The new angular damping.
function LovePhysicsBody:setAngularDamping(damping) end

--- Sets the angular velocity of a Body. The angular velocity is the ''rate of change of angle over t...
---@param w number
--- The new angular velocity, in radians per second
function LovePhysicsBody:setAngularVelocity(w) end

--- Wakes the body up or puts it to sleep.
---@param awake boolean
--- The body sleep status.
function LovePhysicsBody:setAwake(awake) end

--- Set the bullet status of a body. There are two methods to check for body collisions: * at their l...
---@param status boolean
--- The bullet status of the body.
function LovePhysicsBody:setBullet(status) end

--- Set whether a body has fixed rotation. Bodies with fixed rotation don't vary the speed at which t...
---@param isFixed boolean
--- Whether the body should have fixed rotation.
function LovePhysicsBody:setFixedRotation(isFixed) end

--- Sets a new gravity scale factor for the body.
---@param scale number
--- The new gravity scale factor.
function LovePhysicsBody:setGravityScale(scale) end

--- Set the inertia of a body.
---@param inertia number
--- The new moment of inertia, in kilograms * pixel squared.
function LovePhysicsBody:setInertia(inertia) end

--- Sets the linear damping of a Body See Body:getLinearDamping for a definition of linear damping. L...
---@param ld number
--- The new linear damping
function LovePhysicsBody:setLinearDamping(ld) end

--- Sets a new linear velocity for the Body. This function will not accumulate anything; any impulses...
---@param x number
--- The x-component of the velocity vector.
---@param y number
--- The y-component of the velocity vector.
function LovePhysicsBody:setLinearVelocity(x, y) end

--- Sets a new body mass.
---@param mass number
--- The mass, in kilograms.
function LovePhysicsBody:setMass(mass) end

--- Overrides the calculated mass data.
---@param x number
--- The x position of the center of mass.
---@param y number
--- The y position of the center of mass.
---@param mass number
--- The mass of the body.
---@param inertia number
--- The rotational inertia.
function LovePhysicsBody:setMassData(x, y, mass, inertia) end

--- Set the position of the body. Note that this may not be the center of mass of the body. This func...
---@param x number
--- The x position.
---@param y number
--- The y position.
function LovePhysicsBody:setPosition(x, y) end

--- Sets the sleeping behaviour of the body. Should sleeping be allowed, a body at rest will automati...
---@param allowed boolean
--- True if the body is allowed to sleep or false if not.
function LovePhysicsBody:setSleepingAllowed(allowed) end

--- Set the position and angle of the body. Note that the position may not be the center of mass of t...
---@param x number
--- The x component of the position.
---@param y number
--- The y component of the position.
---@param angle number
--- The angle in radians.
function LovePhysicsBody:setTransform(x, y, angle) end

--- Sets a new body type.
---@param type LovePhysicsBodyType
--- The new type.
function LovePhysicsBody:setType(type) end

--- Associates a Lua value with the Body. To delete the reference, explicitly pass nil.
---@param value any
--- The Lua value to associate with the Body.
function LovePhysicsBody:setUserData(value) end

--- Set the x position of the body. This function cannot wake up the body.
---@param x number
--- The x position.
function LovePhysicsBody:setX(x) end

--- Set the y position of the body. This function cannot wake up the body.
---@param y number
--- The y position.
function LovePhysicsBody:setY(y) end

--- A ChainShape consists of multiple line segments. It can be used to create the boundaries of your ...
---@class LovePhysicsChainShape : LovePhysicsShape
--- (also inherits: Object)
LovePhysicsChainShape = {}

--- Returns a child of the shape as an EdgeShape.
---@param index number
--- The index of the child.
---@return LovePhysicsEdgeShape
--- The child as an EdgeShape.
function LovePhysicsChainShape:getChildEdge(index) end

--- Gets the vertex that establishes a connection to the next shape. Setting next and previous ChainS...
---@return number
--- The x-component of the vertex, or nil if ChainShape:setNextVertex hasn't been...
---@return number
--- The y-component of the vertex, or nil if ChainShape:setNextVertex hasn't been...
function LovePhysicsChainShape:getNextVertex() end

--- Returns a point of the shape.
---@param index number
--- The index of the point to return.
---@return number
--- The x-coordinate of the point.
---@return number
--- The y-coordinate of the point.
function LovePhysicsChainShape:getPoint(index) end

--- Returns all points of the shape.
---@return number
--- The x-coordinate of the first point.
---@return number
--- The y-coordinate of the first point.
---@return number
--- The x-coordinate of the second point.
---@return number
--- The y-coordinate of the second point.
function LovePhysicsChainShape:getPoints() end

--- Gets the vertex that establishes a connection to the previous shape. Setting next and previous Ch...
---@return number
--- The x-component of the vertex, or nil if ChainShape:setPreviousVertex hasn't ...
---@return number
--- The y-component of the vertex, or nil if ChainShape:setPreviousVertex hasn't ...
function LovePhysicsChainShape:getPreviousVertex() end

--- Returns the number of vertices the shape has.
---@return number
--- The number of vertices.
function LovePhysicsChainShape:getVertexCount() end

--- Sets a vertex that establishes a connection to the next shape. This can help prevent unwanted col...
---@param x number
--- The x-component of the vertex.
---@param y number
--- The y-component of the vertex.
function LovePhysicsChainShape:setNextVertex(x, y) end

--- Sets a vertex that establishes a connection to the previous shape. This can help prevent unwanted...
---@param x number
--- The x-component of the vertex.
---@param y number
--- The y-component of the vertex.
function LovePhysicsChainShape:setPreviousVertex(x, y) end

--- Circle extends Shape and adds a radius and a local position.
---@class LovePhysicsCircleShape : LovePhysicsShape
--- (also inherits: Object)
LovePhysicsCircleShape = {}

--- Gets the center point of the circle shape.
---@return number
--- The x-component of the center point of the circle.
---@return number
--- The y-component of the center point of the circle.
function LovePhysicsCircleShape:getPoint() end

--- Gets the radius of the circle shape.
---@return number
--- The radius of the circle
function LovePhysicsCircleShape:getRadius() end

--- Sets the location of the center of the circle shape.
---@param x number
--- The x-component of the new center point of the circle.
---@param y number
--- The y-component of the new center point of the circle.
function LovePhysicsCircleShape:setPoint(x, y) end

--- Sets the radius of the circle.
---@param radius number
--- The radius of the circle
function LovePhysicsCircleShape:setRadius(radius) end

--- Contacts are objects created to manage collisions in worlds.
---@class LovePhysicsContact
LovePhysicsContact = {}

--- Gets the child indices of the shapes of the two colliding fixtures. For ChainShapes, an index of ...
---@return number
--- The child index of the first fixture's shape.
---@return number
--- The child index of the second fixture's shape.
function LovePhysicsContact:getChildren() end

--- Gets the two Fixtures that hold the shapes that are in contact.
---@return LovePhysicsFixture
--- The first Fixture.
---@return LovePhysicsFixture
--- The second Fixture.
function LovePhysicsContact:getFixtures() end

--- Get the friction between two shapes that are in contact.
---@return number
--- The friction of the contact.
function LovePhysicsContact:getFriction() end

--- Get the normal vector between two shapes that are in contact. This function returns the coordinat...
---@return number
--- The x component of the normal vector.
---@return number
--- The y component of the normal vector.
function LovePhysicsContact:getNormal() end

--- Returns the contact points of the two colliding fixtures. There can be one or two points.
---@return number
--- The x coordinate of the first contact point.
---@return number
--- The y coordinate of the first contact point.
---@return number
--- The x coordinate of the second contact point.
---@return number
--- The y coordinate of the second contact point.
function LovePhysicsContact:getPositions() end

--- Get the restitution between two shapes that are in contact.
---@return number
--- The restitution between the two shapes.
function LovePhysicsContact:getRestitution() end

--- Returns whether the contact is enabled. The collision will be ignored if a contact gets disabled ...
---@return boolean
--- True if enabled, false otherwise.
function LovePhysicsContact:isEnabled() end

--- Returns whether the two colliding fixtures are touching each other.
---@return boolean
--- True if they touch or false if not.
function LovePhysicsContact:isTouching() end

--- Resets the contact friction to the mixture value of both fixtures.
function LovePhysicsContact:resetFriction() end

--- Resets the contact restitution to the mixture value of both fixtures.
function LovePhysicsContact:resetRestitution() end

--- Enables or disables the contact.
---@param enabled boolean
--- True to enable or false to disable.
function LovePhysicsContact:setEnabled(enabled) end

--- Sets the contact friction.
---@param friction number
--- The contact friction.
function LovePhysicsContact:setFriction(friction) end

--- Sets the contact restitution.
---@param restitution number
--- The contact restitution.
function LovePhysicsContact:setRestitution(restitution) end

--- Keeps two bodies at the same distance.
---@class LovePhysicsDistanceJoint : LovePhysicsJoint
--- (also inherits: Object)
LovePhysicsDistanceJoint = {}

--- Gets the damping ratio.
---@return number
--- The damping ratio.
function LovePhysicsDistanceJoint:getDampingRatio() end

--- Gets the response speed.
---@return number
--- The response speed.
function LovePhysicsDistanceJoint:getFrequency() end

--- Gets the equilibrium distance between the two Bodies.
---@return number
--- The length between the two Bodies.
function LovePhysicsDistanceJoint:getLength() end

--- Sets the damping ratio.
---@param ratio number
--- The damping ratio.
function LovePhysicsDistanceJoint:setDampingRatio(ratio) end

--- Sets the response speed.
---@param Hz number
--- The response speed.
function LovePhysicsDistanceJoint:setFrequency(Hz) end

--- Sets the equilibrium distance between the two Bodies.
---@param l number
--- The length between the two Bodies.
function LovePhysicsDistanceJoint:setLength(l) end

--- A EdgeShape is a line segment. They can be used to create the boundaries of your terrain. The sha...
---@class LovePhysicsEdgeShape : LovePhysicsShape
--- (also inherits: Object)
LovePhysicsEdgeShape = {}

--- Gets the vertex that establishes a connection to the next shape. Setting next and previous EdgeSh...
---@return number
--- The x-component of the vertex, or nil if EdgeShape:setNextVertex hasn't been ...
---@return number
--- The y-component of the vertex, or nil if EdgeShape:setNextVertex hasn't been ...
function LovePhysicsEdgeShape:getNextVertex() end

--- Returns the local coordinates of the edge points.
---@return number
--- The x-component of the first vertex.
---@return number
--- The y-component of the first vertex.
---@return number
--- The x-component of the second vertex.
---@return number
--- The y-component of the second vertex.
function LovePhysicsEdgeShape:getPoints() end

--- Gets the vertex that establishes a connection to the previous shape. Setting next and previous Ed...
---@return number
--- The x-component of the vertex, or nil if EdgeShape:setPreviousVertex hasn't b...
---@return number
--- The y-component of the vertex, or nil if EdgeShape:setPreviousVertex hasn't b...
function LovePhysicsEdgeShape:getPreviousVertex() end

--- Sets a vertex that establishes a connection to the next shape. This can help prevent unwanted col...
---@param x number
--- The x-component of the vertex.
---@param y number
--- The y-component of the vertex.
function LovePhysicsEdgeShape:setNextVertex(x, y) end

--- Sets a vertex that establishes a connection to the previous shape. This can help prevent unwanted...
---@param x number
--- The x-component of the vertex.
---@param y number
--- The y-component of the vertex.
function LovePhysicsEdgeShape:setPreviousVertex(x, y) end

--- Fixtures attach shapes to bodies.
---@class LovePhysicsFixture
LovePhysicsFixture = {}

--- Destroys the fixture.
function LovePhysicsFixture:destroy() end

--- Returns the body to which the fixture is attached.
---@return LovePhysicsBody
--- The parent body.
function LovePhysicsFixture:getBody() end

--- Returns the points of the fixture bounding box. In case the fixture has multiple children a 1-bas...
---@param index? number
--- A bounding box of the fixture.
---@return number
--- The x position of the top-left point.
---@return number
--- The y position of the top-left point.
---@return number
--- The x position of the bottom-right point.
---@return number
--- The y position of the bottom-right point.
function LovePhysicsFixture:getBoundingBox(index) end

--- Returns the categories the fixture belongs to.
---@return number
--- The categories.
function LovePhysicsFixture:getCategory() end

--- Returns the density of the fixture.
---@return number
--- The fixture density in kilograms per square meter.
function LovePhysicsFixture:getDensity() end

--- Returns the filter data of the fixture. Categories and masks are encoded as the bits of a 16-bit ...
---@return number
--- The categories as an integer from 0 to 65535.
---@return number
--- The mask as an integer from 0 to 65535.
---@return number
--- The group as an integer from -32768 to 32767.
function LovePhysicsFixture:getFilterData() end

--- Returns the friction of the fixture.
---@return number
--- The fixture friction.
function LovePhysicsFixture:getFriction() end

--- Returns the group the fixture belongs to. Fixtures with the same group will always collide if the...
---@return number
--- The group of the fixture.
function LovePhysicsFixture:getGroupIndex() end

--- Returns which categories this fixture should '''NOT''' collide with.
---@return number
--- The masks.
function LovePhysicsFixture:getMask() end

--- Returns the mass, its center and the rotational inertia.
---@return number
--- The x position of the center of mass.
---@return number
--- The y position of the center of mass.
---@return number
--- The mass of the fixture.
---@return number
--- The rotational inertia.
function LovePhysicsFixture:getMassData() end

--- Returns the restitution of the fixture.
---@return number
--- The fixture restitution.
function LovePhysicsFixture:getRestitution() end

--- Returns the shape of the fixture. This shape is a reference to the actual data used in the simula...
---@return LovePhysicsShape
--- The fixture's shape.
function LovePhysicsFixture:getShape() end

--- Returns the Lua value associated with this fixture.
---@return any
--- The Lua value associated with the fixture.
function LovePhysicsFixture:getUserData() end

--- Gets whether the Fixture is destroyed. Destroyed fixtures cannot be used.
---@return boolean
--- Whether the Fixture is destroyed.
function LovePhysicsFixture:isDestroyed() end

--- Returns whether the fixture is a sensor.
---@return boolean
--- If the fixture is a sensor.
function LovePhysicsFixture:isSensor() end

--- Casts a ray against the shape of the fixture and returns the surface normal vector and the line p...
---@param x1 number
--- The x position of the input line starting point.
---@param y1 number
--- The y position of the input line starting point.
---@param x2 number
--- The x position of the input line end point.
---@param y2 number
--- The y position of the input line end point.
---@param maxFraction number
--- Ray length parameter.
---@param childIndex? number
--- The index of the child the ray gets cast against.
---@return number
--- The x component of the normal vector of the edge where the ray hit the shape.
---@return number
--- The y component of the normal vector of the edge where the ray hit the shape.
---@return number
--- The position on the input line where the intersection happened as a factor of...
function LovePhysicsFixture:rayCast(x1, y1, x2, y2, maxFraction, childIndex) end

--- Sets the categories the fixture belongs to. There can be up to 16 categories represented as a num...
---@param ___ number
--- The categories.
function LovePhysicsFixture:setCategory(___) end

--- Sets the density of the fixture. Call Body:resetMassData if this needs to take effect immediately.
---@param density number
--- The fixture density in kilograms per square meter.
function LovePhysicsFixture:setDensity(density) end

--- Sets the filter data of the fixture. Groups, categories, and mask can be used to define the colli...
---@param categories number
--- The categories as an integer from 0 to 65535.
---@param mask number
--- The mask as an integer from 0 to 65535.
---@param group number
--- The group as an integer from -32768 to 32767.
function LovePhysicsFixture:setFilterData(categories, mask, group) end

--- Sets the friction of the fixture. Friction determines how shapes react when they 'slide' along ot...
---@param friction number
--- The fixture friction.
function LovePhysicsFixture:setFriction(friction) end

--- Sets the group the fixture belongs to. Fixtures with the same group will always collide if the gr...
---@param group number
--- The group as an integer from -32768 to 32767.
function LovePhysicsFixture:setGroupIndex(group) end

--- Sets the category mask of the fixture. There can be up to 16 categories represented as a number f...
---@param ___ number
--- The masks.
function LovePhysicsFixture:setMask(___) end

--- Sets the restitution of the fixture.
---@param restitution number
--- The fixture restitution.
function LovePhysicsFixture:setRestitution(restitution) end

--- Sets whether the fixture should act as a sensor. Sensors do not cause collision responses, but th...
---@param sensor boolean
--- The sensor status.
function LovePhysicsFixture:setSensor(sensor) end

--- Associates a Lua value with the fixture. To delete the reference, explicitly pass nil.
---@param value any
--- The Lua value to associate with the fixture.
function LovePhysicsFixture:setUserData(value) end

--- Checks if a point is inside the shape of the fixture.
---@param x number
--- The x position of the point.
---@param y number
--- The y position of the point.
---@return boolean
--- True if the point is inside or false if it is outside.
function LovePhysicsFixture:testPoint(x, y) end

--- A FrictionJoint applies friction to a body.
---@class LovePhysicsFrictionJoint : LovePhysicsJoint
--- (also inherits: Object)
LovePhysicsFrictionJoint = {}

--- Gets the maximum friction force in Newtons.
---@return number
--- Maximum force in Newtons.
function LovePhysicsFrictionJoint:getMaxForce() end

--- Gets the maximum friction torque in Newton-meters.
---@return number
--- Maximum torque in Newton-meters.
function LovePhysicsFrictionJoint:getMaxTorque() end

--- Sets the maximum friction force in Newtons.
---@param maxForce number
--- Max force in Newtons.
function LovePhysicsFrictionJoint:setMaxForce(maxForce) end

--- Sets the maximum friction torque in Newton-meters.
---@param torque number
--- Maximum torque in Newton-meters.
function LovePhysicsFrictionJoint:setMaxTorque(torque) end

--- Keeps bodies together in such a way that they act like gears.
---@class LovePhysicsGearJoint : LovePhysicsJoint
--- (also inherits: Object)
LovePhysicsGearJoint = {}

--- Get the Joints connected by this GearJoint.
---@return LovePhysicsJoint
--- The first connected Joint.
---@return LovePhysicsJoint
--- The second connected Joint.
function LovePhysicsGearJoint:getJoints() end

--- Get the ratio of a gear joint.
---@return number
--- The ratio of the joint.
function LovePhysicsGearJoint:getRatio() end

--- Set the ratio of a gear joint.
---@param ratio number
--- The new ratio of the joint.
function LovePhysicsGearJoint:setRatio(ratio) end

--- Attach multiple bodies together to interact in unique ways.
---@class LovePhysicsJoint
LovePhysicsJoint = {}

--- Explicitly destroys the Joint. An error will occur if you attempt to use the object after calling...
function LovePhysicsJoint:destroy() end

--- Get the anchor points of the joint.
---@return number
--- The x-component of the anchor on Body 1.
---@return number
--- The y-component of the anchor on Body 1.
---@return number
--- The x-component of the anchor on Body 2.
---@return number
--- The y-component of the anchor on Body 2.
function LovePhysicsJoint:getAnchors() end

--- Gets the bodies that the Joint is attached to.
---@return LovePhysicsBody
--- The first Body.
---@return LovePhysicsBody
--- The second Body.
function LovePhysicsJoint:getBodies() end

--- Gets whether the connected Bodies collide.
---@return boolean
--- True if they collide, false otherwise.
function LovePhysicsJoint:getCollideConnected() end

--- Returns the reaction force in newtons on the second body
---@param x number
--- How long the force applies. Usually the inverse time step or 1/dt.
---@return number
--- The x-component of the force.
---@return number
--- The y-component of the force.
function LovePhysicsJoint:getReactionForce(x) end

--- Returns the reaction torque on the second body.
---@param invdt number
--- How long the force applies. Usually the inverse time step or 1/dt.
---@return number
--- The reaction torque on the second body.
function LovePhysicsJoint:getReactionTorque(invdt) end

--- Gets a string representing the type.
---@return LovePhysicsJointType
--- A string with the name of the Joint type.
function LovePhysicsJoint:getType() end

--- Returns the Lua value associated with this Joint.
---@return any
--- The Lua value associated with the Joint.
function LovePhysicsJoint:getUserData() end

--- Gets whether the Joint is destroyed. Destroyed joints cannot be used.
---@return boolean
--- Whether the Joint is destroyed.
function LovePhysicsJoint:isDestroyed() end

--- Associates a Lua value with the Joint. To delete the reference, explicitly pass nil.
---@param value any
--- The Lua value to associate with the Joint.
function LovePhysicsJoint:setUserData(value) end

--- Controls the relative motion between two Bodies. Position and rotation offsets can be specified, ...
---@class LovePhysicsMotorJoint : LovePhysicsJoint
--- (also inherits: Object)
LovePhysicsMotorJoint = {}

--- Gets the target angular offset between the two Bodies the Joint is attached to.
---@return number
--- The target angular offset in radians: the second body's angle minus the first...
function LovePhysicsMotorJoint:getAngularOffset() end

--- Gets the target linear offset between the two Bodies the Joint is attached to.
---@return number
--- The x component of the target linear offset, relative to the first Body.
---@return number
--- The y component of the target linear offset, relative to the first Body.
function LovePhysicsMotorJoint:getLinearOffset() end

--- Sets the target angluar offset between the two Bodies the Joint is attached to.
---@param angleoffset number
--- The target angular offset in radians: the second body's angle minus the first...
function LovePhysicsMotorJoint:setAngularOffset(angleoffset) end

--- Sets the target linear offset between the two Bodies the Joint is attached to.
---@param x number
--- The x component of the target linear offset, relative to the first Body.
---@param y number
--- The y component of the target linear offset, relative to the first Body.
function LovePhysicsMotorJoint:setLinearOffset(x, y) end

--- For controlling objects with the mouse.
---@class LovePhysicsMouseJoint : LovePhysicsJoint
--- (also inherits: Object)
LovePhysicsMouseJoint = {}

--- Returns the damping ratio.
---@return number
--- The new damping ratio.
function LovePhysicsMouseJoint:getDampingRatio() end

--- Returns the frequency.
---@return number
--- The frequency in hertz.
function LovePhysicsMouseJoint:getFrequency() end

--- Gets the highest allowed force.
---@return number
--- The max allowed force.
function LovePhysicsMouseJoint:getMaxForce() end

--- Gets the target point.
---@return number
--- The x-component of the target.
---@return number
--- The x-component of the target.
function LovePhysicsMouseJoint:getTarget() end

--- Sets a new damping ratio.
---@param ratio number
--- The new damping ratio.
function LovePhysicsMouseJoint:setDampingRatio(ratio) end

--- Sets a new frequency.
---@param freq number
--- The new frequency in hertz.
function LovePhysicsMouseJoint:setFrequency(freq) end

--- Sets the highest allowed force.
---@param f number
--- The max allowed force.
function LovePhysicsMouseJoint:setMaxForce(f) end

--- Sets the target point.
---@param x number
--- The x-component of the target.
---@param y number
--- The y-component of the target.
function LovePhysicsMouseJoint:setTarget(x, y) end

--- A PolygonShape is a convex polygon with up to 8 vertices.
---@class LovePhysicsPolygonShape : LovePhysicsShape
--- (also inherits: Object)
LovePhysicsPolygonShape = {}

--- Get the local coordinates of the polygon's vertices. This function has a variable number of retur...
---@return number
--- The x-component of the first vertex.
---@return number
--- The y-component of the first vertex.
---@return number
--- The x-component of the second vertex.
---@return number
--- The y-component of the second vertex.
function LovePhysicsPolygonShape:getPoints() end

--- Restricts relative motion between Bodies to one shared axis.
---@class LovePhysicsPrismaticJoint : LovePhysicsJoint
--- (also inherits: Object)
LovePhysicsPrismaticJoint = {}

--- Checks whether the limits are enabled.
---@return boolean
--- True if enabled, false otherwise.
function LovePhysicsPrismaticJoint:areLimitsEnabled() end

--- Gets the world-space axis vector of the Prismatic Joint.
---@return number
--- The x-axis coordinate of the world-space axis vector.
---@return number
--- The y-axis coordinate of the world-space axis vector.
function LovePhysicsPrismaticJoint:getAxis() end

--- Get the current joint angle speed.
---@return number
--- Joint angle speed in meters/second.
function LovePhysicsPrismaticJoint:getJointSpeed() end

--- Get the current joint translation.
---@return number
--- Joint translation, usually in meters..
function LovePhysicsPrismaticJoint:getJointTranslation() end

--- Gets the joint limits.
---@return number
--- The lower limit, usually in meters.
---@return number
--- The upper limit, usually in meters.
function LovePhysicsPrismaticJoint:getLimits() end

--- Gets the lower limit.
---@return number
--- The lower limit, usually in meters.
function LovePhysicsPrismaticJoint:getLowerLimit() end

--- Gets the maximum motor force.
---@return number
--- The maximum motor force, usually in N.
function LovePhysicsPrismaticJoint:getMaxMotorForce() end

--- Returns the current motor force.
---@param invdt number
--- How long the force applies. Usually the inverse time step or 1/dt.
---@return number
--- The force on the motor in newtons.
function LovePhysicsPrismaticJoint:getMotorForce(invdt) end

--- Gets the motor speed.
---@return number
--- The motor speed, usually in meters per second.
function LovePhysicsPrismaticJoint:getMotorSpeed() end

--- Gets the reference angle.
---@return number
--- The reference angle in radians.
function LovePhysicsPrismaticJoint:getReferenceAngle() end

--- Gets the upper limit.
---@return number
--- The upper limit, usually in meters.
function LovePhysicsPrismaticJoint:getUpperLimit() end

--- Checks whether the motor is enabled.
---@return boolean
--- True if enabled, false if disabled.
function LovePhysicsPrismaticJoint:isMotorEnabled() end

--- Sets the limits.
---@param lower number
--- The lower limit, usually in meters.
---@param upper number
--- The upper limit, usually in meters.
function LovePhysicsPrismaticJoint:setLimits(lower, upper) end

--- Enables/disables the joint limit.
---@return boolean
--- True if enabled, false if disabled.
function LovePhysicsPrismaticJoint:setLimitsEnabled() end

--- Sets the lower limit.
---@param lower number
--- The lower limit, usually in meters.
function LovePhysicsPrismaticJoint:setLowerLimit(lower) end

--- Set the maximum motor force.
---@param f number
--- The maximum motor force, usually in N.
function LovePhysicsPrismaticJoint:setMaxMotorForce(f) end

--- Enables/disables the joint motor.
---@param enable boolean
--- True to enable, false to disable.
function LovePhysicsPrismaticJoint:setMotorEnabled(enable) end

--- Sets the motor speed.
---@param s number
--- The motor speed, usually in meters per second.
function LovePhysicsPrismaticJoint:setMotorSpeed(s) end

--- Sets the upper limit.
---@param upper number
--- The upper limit, usually in meters.
function LovePhysicsPrismaticJoint:setUpperLimit(upper) end

--- Allows you to simulate bodies connected through pulleys.
---@class LovePhysicsPulleyJoint : LovePhysicsJoint
--- (also inherits: Object)
LovePhysicsPulleyJoint = {}

--- Get the total length of the rope.
---@return number
--- The length of the rope in the joint.
function LovePhysicsPulleyJoint:getConstant() end

--- Get the ground anchor positions in world coordinates.
---@return number
--- The x coordinate of the first anchor.
---@return number
--- The y coordinate of the first anchor.
---@return number
--- The x coordinate of the second anchor.
---@return number
--- The y coordinate of the second anchor.
function LovePhysicsPulleyJoint:getGroundAnchors() end

--- Get the current length of the rope segment attached to the first body.
---@return number
--- The length of the rope segment.
function LovePhysicsPulleyJoint:getLengthA() end

--- Get the current length of the rope segment attached to the second body.
---@return number
--- The length of the rope segment.
function LovePhysicsPulleyJoint:getLengthB() end

--- Get the maximum lengths of the rope segments.
---@return number
--- The maximum length of the first rope segment.
---@return number
--- The maximum length of the second rope segment.
function LovePhysicsPulleyJoint:getMaxLengths() end

--- Get the pulley ratio.
---@return number
--- The pulley ratio of the joint.
function LovePhysicsPulleyJoint:getRatio() end

--- Set the total length of the rope. Setting a new length for the rope updates the maximum length va...
---@param length number
--- The new length of the rope in the joint.
function LovePhysicsPulleyJoint:setConstant(length) end

--- Set the maximum lengths of the rope segments. The physics module also imposes maximum values for ...
---@param max1 number
--- The new maximum length of the first segment.
---@param max2 number
--- The new maximum length of the second segment.
function LovePhysicsPulleyJoint:setMaxLengths(max1, max2) end

--- Set the pulley ratio.
---@param ratio number
--- The new pulley ratio of the joint.
function LovePhysicsPulleyJoint:setRatio(ratio) end

--- Allow two Bodies to revolve around a shared point.
---@class LovePhysicsRevoluteJoint : LovePhysicsJoint
--- (also inherits: Object)
LovePhysicsRevoluteJoint = {}

--- Checks whether limits are enabled.
---@return boolean
--- True if enabled, false otherwise.
function LovePhysicsRevoluteJoint:areLimitsEnabled() end

--- Get the current joint angle.
---@return number
--- The joint angle in radians.
function LovePhysicsRevoluteJoint:getJointAngle() end

--- Get the current joint angle speed.
---@return number
--- Joint angle speed in radians/second.
function LovePhysicsRevoluteJoint:getJointSpeed() end

--- Gets the joint limits.
---@return number
--- The lower limit, in radians.
---@return number
--- The upper limit, in radians.
function LovePhysicsRevoluteJoint:getLimits() end

--- Gets the lower limit.
---@return number
--- The lower limit, in radians.
function LovePhysicsRevoluteJoint:getLowerLimit() end

--- Gets the maximum motor force.
---@return number
--- The maximum motor force, in Nm.
function LovePhysicsRevoluteJoint:getMaxMotorTorque() end

--- Gets the motor speed.
---@return number
--- The motor speed, radians per second.
function LovePhysicsRevoluteJoint:getMotorSpeed() end

--- Get the current motor force.
---@return number
--- The current motor force, in Nm.
function LovePhysicsRevoluteJoint:getMotorTorque() end

--- Gets the reference angle.
---@return number
--- The reference angle in radians.
function LovePhysicsRevoluteJoint:getReferenceAngle() end

--- Gets the upper limit.
---@return number
--- The upper limit, in radians.
function LovePhysicsRevoluteJoint:getUpperLimit() end

--- Checks whether limits are enabled.
---@return boolean
--- True if enabled, false otherwise.
function LovePhysicsRevoluteJoint:hasLimitsEnabled() end

--- Checks whether the motor is enabled.
---@return boolean
--- True if enabled, false if disabled.
function LovePhysicsRevoluteJoint:isMotorEnabled() end

--- Sets the limits.
---@param lower number
--- The lower limit, in radians.
---@param upper number
--- The upper limit, in radians.
function LovePhysicsRevoluteJoint:setLimits(lower, upper) end

--- Enables/disables the joint limit.
---@param enable boolean
--- True to enable, false to disable.
function LovePhysicsRevoluteJoint:setLimitsEnabled(enable) end

--- Sets the lower limit.
---@param lower number
--- The lower limit, in radians.
function LovePhysicsRevoluteJoint:setLowerLimit(lower) end

--- Set the maximum motor force.
---@param f number
--- The maximum motor force, in Nm.
function LovePhysicsRevoluteJoint:setMaxMotorTorque(f) end

--- Enables/disables the joint motor.
---@param enable boolean
--- True to enable, false to disable.
function LovePhysicsRevoluteJoint:setMotorEnabled(enable) end

--- Sets the motor speed.
---@param s number
--- The motor speed, radians per second.
function LovePhysicsRevoluteJoint:setMotorSpeed(s) end

--- Sets the upper limit.
---@param upper number
--- The upper limit, in radians.
function LovePhysicsRevoluteJoint:setUpperLimit(upper) end

--- The RopeJoint enforces a maximum distance between two points on two bodies. It has no other effect.
---@class LovePhysicsRopeJoint : LovePhysicsJoint
--- (also inherits: Object)
LovePhysicsRopeJoint = {}

--- Gets the maximum length of a RopeJoint.
---@return number
--- The maximum length of the RopeJoint.
function LovePhysicsRopeJoint:getMaxLength() end

--- Sets the maximum length of a RopeJoint.
---@param maxLength number
--- The new maximum length of the RopeJoint.
function LovePhysicsRopeJoint:setMaxLength(maxLength) end

--- Shapes are solid 2d geometrical objects which handle the mass and collision of a Body in love.phy...
---@class LovePhysicsShape
LovePhysicsShape = {}

--- Returns the points of the bounding box for the transformed shape.
---@param tx number
--- The translation of the shape on the x-axis.
---@param ty number
--- The translation of the shape on the y-axis.
---@param tr number
--- The shape rotation.
---@param childIndex? number
--- The index of the child to compute the bounding box of.
---@return number
--- The x position of the top-left point.
---@return number
--- The y position of the top-left point.
---@return number
--- The x position of the bottom-right point.
---@return number
--- The y position of the bottom-right point.
function LovePhysicsShape:computeAABB(tx, ty, tr, childIndex) end

--- Computes the mass properties for the shape with the specified density.
---@param density number
--- The shape density.
---@return number
--- The x postition of the center of mass.
---@return number
--- The y postition of the center of mass.
---@return number
--- The mass of the shape.
---@return number
--- The rotational inertia.
function LovePhysicsShape:computeMass(density) end

--- Returns the number of children the shape has.
---@return number
--- The number of children.
function LovePhysicsShape:getChildCount() end

--- Gets the radius of the shape.
---@return number
--- The radius of the shape.
function LovePhysicsShape:getRadius() end

--- Gets a string representing the Shape. This function can be useful for conditional debug drawing.
---@return LovePhysicsShapeType
--- The type of the Shape.
function LovePhysicsShape:getType() end

--- Casts a ray against the shape and returns the surface normal vector and the line position where t...
---@param x1 number
--- The x position of the input line starting point.
---@param y1 number
--- The y position of the input line starting point.
---@param x2 number
--- The x position of the input line end point.
---@param y2 number
--- The y position of the input line end point.
---@param maxFraction number
--- Ray length parameter.
---@param tx number
--- The translation of the shape on the x-axis.
---@param ty number
--- The translation of the shape on the y-axis.
---@param tr number
--- The shape rotation.
---@param childIndex? number
--- The index of the child the ray gets cast against.
---@return number
--- The x component of the normal vector of the edge where the ray hit the shape.
---@return number
--- The y component of the normal vector of the edge where the ray hit the shape.
---@return number
--- The position on the input line where the intersection happened as a factor of...
function LovePhysicsShape:rayCast(x1, y1, x2, y2, maxFraction, tx, ty, tr, childIndex) end

--- This is particularly useful for mouse interaction with the shapes. By looping through all shapes ...
---@param tx number
--- Translates the shape along the x-axis.
---@param ty number
--- Translates the shape along the y-axis.
---@param tr number
--- Rotates the shape.
---@param x number
--- The x-component of the point.
---@param y number
--- The y-component of the point.
---@return boolean
--- True if inside, false if outside
function LovePhysicsShape:testPoint(tx, ty, tr, x, y) end

--- A WeldJoint essentially glues two bodies together.
---@class LovePhysicsWeldJoint : LovePhysicsJoint
--- (also inherits: Object)
LovePhysicsWeldJoint = {}

--- Returns the damping ratio of the joint.
---@return number
--- The damping ratio.
function LovePhysicsWeldJoint:getDampingRatio() end

--- Returns the frequency.
---@return number
--- The frequency in hertz.
function LovePhysicsWeldJoint:getFrequency() end

--- Gets the reference angle.
---@return number
--- The reference angle in radians.
function LovePhysicsWeldJoint:getReferenceAngle() end

--- Sets a new damping ratio.
---@param ratio number
--- The new damping ratio.
function LovePhysicsWeldJoint:setDampingRatio(ratio) end

--- Sets a new frequency.
---@param freq number
--- The new frequency in hertz.
function LovePhysicsWeldJoint:setFrequency(freq) end

--- Restricts a point on the second body to a line on the first body.
---@class LovePhysicsWheelJoint : LovePhysicsJoint
--- (also inherits: Object)
LovePhysicsWheelJoint = {}

--- Gets the world-space axis vector of the Wheel Joint.
---@return number
--- The x-axis coordinate of the world-space axis vector.
---@return number
--- The y-axis coordinate of the world-space axis vector.
function LovePhysicsWheelJoint:getAxis() end

--- Returns the current joint translation speed.
---@return number
--- The translation speed of the joint in meters per second.
function LovePhysicsWheelJoint:getJointSpeed() end

--- Returns the current joint translation.
---@return number
--- The translation of the joint in meters.
function LovePhysicsWheelJoint:getJointTranslation() end

--- Returns the maximum motor torque.
---@return number
--- The maximum torque of the joint motor in newton meters.
function LovePhysicsWheelJoint:getMaxMotorTorque() end

--- Returns the speed of the motor.
---@return number
--- The speed of the joint motor in radians per second.
function LovePhysicsWheelJoint:getMotorSpeed() end

--- Returns the current torque on the motor.
---@param invdt number
--- How long the force applies. Usually the inverse time step or 1/dt.
---@return number
--- The torque on the motor in newton meters.
function LovePhysicsWheelJoint:getMotorTorque(invdt) end

--- Returns the damping ratio.
---@return number
--- The damping ratio.
function LovePhysicsWheelJoint:getSpringDampingRatio() end

--- Returns the spring frequency.
---@return number
--- The frequency in hertz.
function LovePhysicsWheelJoint:getSpringFrequency() end

--- Checks if the joint motor is running.
---@return boolean
--- The status of the joint motor.
function LovePhysicsWheelJoint:isMotorEnabled() end

--- Sets a new maximum motor torque.
---@param maxTorque number
--- The new maximum torque for the joint motor in newton meters.
function LovePhysicsWheelJoint:setMaxMotorTorque(maxTorque) end

--- Starts and stops the joint motor.
---@param enable boolean
--- True turns the motor on and false turns it off.
function LovePhysicsWheelJoint:setMotorEnabled(enable) end

--- Sets a new speed for the motor.
---@param speed number
--- The new speed for the joint motor in radians per second.
function LovePhysicsWheelJoint:setMotorSpeed(speed) end

--- Sets a new damping ratio.
---@param ratio number
--- The new damping ratio.
function LovePhysicsWheelJoint:setSpringDampingRatio(ratio) end

--- Sets a new spring frequency.
---@param freq number
--- The new frequency in hertz.
function LovePhysicsWheelJoint:setSpringFrequency(freq) end

--- A world is an object that contains all bodies and joints.
---@class LovePhysicsWorld
LovePhysicsWorld = {}

--- Destroys the world, taking all bodies, joints, fixtures and their shapes with it. An error will o...
function LovePhysicsWorld:destroy() end

--- Returns a table with all bodies.
---@return table
--- A sequence with all bodies.
function LovePhysicsWorld:getBodies() end

--- Returns the number of bodies in the world.
---@return number
--- The number of bodies in the world.
function LovePhysicsWorld:getBodyCount() end

--- Returns functions for the callbacks during the world update.
---@return function
--- Gets called when two fixtures begin to overlap.
---@return function
--- Gets called when two fixtures cease to overlap.
---@return function
--- Gets called before a collision gets resolved.
---@return function
--- Gets called after the collision has been resolved.
function LovePhysicsWorld:getCallbacks() end

--- Returns the number of contacts in the world.
---@return number
--- The number of contacts in the world.
function LovePhysicsWorld:getContactCount() end

--- Returns the function for collision filtering.
---@return function
--- The function that handles the contact filtering.
function LovePhysicsWorld:getContactFilter() end

--- Returns a table with all Contacts.
---@return table
--- A sequence with all Contacts.
function LovePhysicsWorld:getContacts() end

--- Get the gravity of the world.
---@return number
--- The x component of gravity.
---@return number
--- The y component of gravity.
function LovePhysicsWorld:getGravity() end

--- Returns the number of joints in the world.
---@return number
--- The number of joints in the world.
function LovePhysicsWorld:getJointCount() end

--- Returns a table with all joints.
---@return table
--- A sequence with all joints.
function LovePhysicsWorld:getJoints() end

--- Gets whether the World is destroyed. Destroyed worlds cannot be used.
---@return boolean
--- Whether the World is destroyed.
function LovePhysicsWorld:isDestroyed() end

--- Returns if the world is updating its state. This will return true inside the callbacks from World...
---@return boolean
--- Will be true if the world is in the process of updating its state.
function LovePhysicsWorld:isLocked() end

--- Gets the sleep behaviour of the world.
---@return boolean
--- True if bodies in the world are allowed to sleep, or false if not.
function LovePhysicsWorld:isSleepingAllowed() end

--- Calls a function for each fixture inside the specified area by searching for any overlapping boun...
---@param topLeftX number
--- The x position of the top-left point.
---@param topLeftY number
--- The y position of the top-left point.
---@param bottomRightX number
--- The x position of the bottom-right point.
---@param bottomRightY number
--- The y position of the bottom-right point.
---@param callback function
--- This function gets passed one argument, the fixture, and should return a bool...
function LovePhysicsWorld:queryBoundingBox(topLeftX, topLeftY, bottomRightX, bottomRightY, callback) end

--- Casts a ray and calls a function for each fixtures it intersects.
---@param x1 number
--- The x position of the starting point of the ray.
---@param y1 number
--- The x position of the starting point of the ray.
---@param x2 number
--- The x position of the end point of the ray.
---@param y2 number
--- The x value of the surface normal vector of the shape edge.
---@param callback function
--- A function called for each fixture intersected by the ray. The function gets ...
function LovePhysicsWorld:rayCast(x1, y1, x2, y2, callback) end

--- Sets functions for the collision callbacks during the world update. Four Lua functions can be giv...
---@param beginContact function
--- Gets called when two fixtures begin to overlap.
---@param endContact function
--- Gets called when two fixtures cease to overlap. This will also be called outs...
---@param preSolve? function
--- Gets called before a collision gets resolved.
---@param postSolve? function
--- Gets called after the collision has been resolved.
function LovePhysicsWorld:setCallbacks(beginContact, endContact, preSolve, postSolve) end

--- Sets a function for collision filtering. If the group and category filtering doesn't generate a c...
---@param filter function
--- The function handling the contact filtering.
function LovePhysicsWorld:setContactFilter(filter) end

--- Set the gravity of the world.
---@param x number
--- The x component of gravity.
---@param y number
--- The y component of gravity.
function LovePhysicsWorld:setGravity(x, y) end

--- Sets the sleep behaviour of the world.
---@param allow boolean
--- True if bodies in the world are allowed to sleep, or false if not.
function LovePhysicsWorld:setSleepingAllowed(allow) end

--- Translates the World's origin. Useful in large worlds where floating point precision issues becom...
---@param x number
--- The x component of the new origin with respect to the old origin.
---@param y number
--- The y component of the new origin with respect to the old origin.
function LovePhysicsWorld:translateOrigin(x, y) end

--- Update the state of the world.
---@param dt number
--- The time (in seconds) to advance the physics simulation.
---@param velocityiterations? number
--- The maximum number of steps used to determine the new velocities when resolvi...
---@param positioniterations? number
--- The maximum number of steps used to determine the new positions when resolvin...
function LovePhysicsWorld:update(dt, velocityiterations, positioniterations) end

--- Returns the two closest points between two fixtures and their distance.
---@param fixture1 LovePhysicsFixture
--- The first fixture.
---@param fixture2 LovePhysicsFixture
--- The second fixture.
---@return number
--- The distance of the two points.
---@return number
--- The x-coordinate of the first point.
---@return number
--- The y-coordinate of the first point.
---@return number
--- The x-coordinate of the second point.
---@return number
--- The y-coordinate of the second point.
function love.physics.getDistance(fixture1, fixture2) end

--- Returns the meter scale factor. All coordinates in the physics module are divided by this number,...
---@return number
--- The scale factor as an integer.
function love.physics.getMeter() end

--- Creates a new body. There are three types of bodies. * Static bodies do not move, have a infinite...
---@param world LovePhysicsWorld
--- The world to create the body in.
---@param x? number
--- The x position of the body.
---@param y? number
--- The y position of the body.
---@param type? LovePhysicsBodyType
--- The type of the body.
---@return LovePhysicsBody
--- A new body.
function love.physics.newBody(world, x, y, type) end

--- Creates a new ChainShape.
---@param loop boolean
--- If the chain should loop back to the first point.
---@param x1 number
--- The x position of the first point.
---@param y1 number
--- The y position of the first point.
---@param x2 number
--- The x position of the second point.
---@param y2 number
--- The y position of the second point.
---@param ___ number
--- Additional point positions.
---@overload fun(boolean, table)
---@return LovePhysicsChainShape
--- The new shape.
function love.physics.newChainShape(loop, x1, y1, x2, y2, ___) end

--- Creates a new CircleShape.
---@param x number
--- The x position of the circle.
---@param y number
--- The y position of the circle.
---@param radius number
--- The radius of the circle.
---@overload fun(number)
---@return LovePhysicsCircleShape
--- The new shape.
function love.physics.newCircleShape(x, y, radius) end

--- Creates a DistanceJoint between two bodies. This joint constrains the distance between two points...
---@param body1 LovePhysicsBody
--- The first body to attach to the joint.
---@param body2 LovePhysicsBody
--- The second body to attach to the joint.
---@param x1 number
--- The x position of the first anchor point (world space).
---@param y1 number
--- The y position of the first anchor point (world space).
---@param x2 number
--- The x position of the second anchor point (world space).
---@param y2 number
--- The y position of the second anchor point (world space).
---@param collideConnected? boolean
--- Specifies whether the two bodies should collide with each other.
---@return LovePhysicsDistanceJoint
--- The new distance joint.
function love.physics.newDistanceJoint(body1, body2, x1, y1, x2, y2, collideConnected) end

--- Creates a new EdgeShape.
---@param x1 number
--- The x position of the first point.
---@param y1 number
--- The y position of the first point.
---@param x2 number
--- The x position of the second point.
---@param y2 number
--- The y position of the second point.
---@return LovePhysicsEdgeShape
--- The new shape.
function love.physics.newEdgeShape(x1, y1, x2, y2) end

--- Creates and attaches a Fixture to a body. Note that the Shape object is copied rather than kept a...
---@param body LovePhysicsBody
--- The body which gets the fixture attached.
---@param shape LovePhysicsShape
--- The shape to be copied to the fixture.
---@param density? number
--- The density of the fixture.
---@return LovePhysicsFixture
--- The new fixture.
function love.physics.newFixture(body, shape, density) end

--- Create a friction joint between two bodies. A FrictionJoint applies friction to a body.
---@param body1 LovePhysicsBody
--- The first body to attach to the joint.
---@param body2 LovePhysicsBody
--- The second body to attach to the joint.
---@param x1 number
--- The x position of the first anchor point.
---@param y1 number
--- The y position of the first anchor point.
---@param x2 number
--- The x position of the second anchor point.
---@param y2 number
--- The y position of the second anchor point.
---@param collideConnected? boolean
--- Specifies whether the two bodies should collide with each other.
---@overload fun(LovePhysicsBody, LovePhysicsBody, number, number, boolean?)
---@return LovePhysicsFrictionJoint
--- The new FrictionJoint.
function love.physics.newFrictionJoint(body1, body2, x1, y1, x2, y2, collideConnected) end

--- Create a GearJoint connecting two Joints. The gear joint connects two joints that must be either ...
---@param joint1 LovePhysicsJoint
--- The first joint to connect with a gear joint.
---@param joint2 LovePhysicsJoint
--- The second joint to connect with a gear joint.
---@param ratio? number
--- The gear ratio.
---@param collideConnected? boolean
--- Specifies whether the two bodies should collide with each other.
---@return LovePhysicsGearJoint
--- The new gear joint.
function love.physics.newGearJoint(joint1, joint2, ratio, collideConnected) end

--- Creates a joint between two bodies which controls the relative motion between them. Position and ...
---@param body1 LovePhysicsBody
--- The first body to attach to the joint.
---@param body2 LovePhysicsBody
--- The second body to attach to the joint.
---@param correctionFactor? number
--- The joint's initial position correction factor, in the range of 1.
---@param collideConnected? boolean
--- Specifies whether the two bodies should collide with each other.
---@overload fun(LovePhysicsBody, LovePhysicsBody, number?)
---@return LovePhysicsMotorJoint
--- The new MotorJoint.
function love.physics.newMotorJoint(body1, body2, correctionFactor, collideConnected) end

--- Create a joint between a body and the mouse. This joint actually connects the body to a fixed poi...
---@param body LovePhysicsBody
--- The body to attach to the mouse.
---@param x number
--- The x position of the connecting point.
---@param y number
--- The y position of the connecting point.
---@return LovePhysicsMouseJoint
--- The new mouse joint.
function love.physics.newMouseJoint(body, x, y) end

--- Creates a new PolygonShape. This shape can have 8 vertices at most, and must form a convex shape.
---@param x1 number
--- The x position of the first point.
---@param y1 number
--- The y position of the first point.
---@param x2 number
--- The x position of the second point.
---@param y2 number
--- The y position of the second point.
---@param x3 number
--- The x position of the third point.
---@param y3 number
--- The y position of the third point.
---@param ___ number
--- You can continue passing more point positions to create the PolygonShape.
---@overload fun(table)
---@return LovePhysicsPolygonShape
--- A new PolygonShape.
function love.physics.newPolygonShape(x1, y1, x2, y2, x3, y3, ___) end

--- Creates a PrismaticJoint between two bodies. A prismatic joint constrains two bodies to move rela...
---@param body1 LovePhysicsBody
--- The first body to connect with a prismatic joint.
---@param body2 LovePhysicsBody
--- The second body to connect with a prismatic joint.
---@param x1 number
--- The x coordinate of the first anchor point.
---@param y1 number
--- The y coordinate of the first anchor point.
---@param x2 number
--- The x coordinate of the second anchor point.
---@param y2 number
--- The y coordinate of the second anchor point.
---@param ax number
--- The x coordinate of the axis unit vector.
---@param ay number
--- The y coordinate of the axis unit vector.
---@param collideConnected? boolean
--- Specifies whether the two bodies should collide with each other.
---@param referenceAngle? number
--- The reference angle between body1 and body2, in radians.
---@overload fun(LovePhysicsBody, LovePhysicsBody, number, number, number, number, boolean?)
---@overload fun(LovePhysicsBody, LovePhysicsBody, number, number, number, number, number, number, boolean?)
---@return LovePhysicsPrismaticJoint
--- The new prismatic joint.
function love.physics.newPrismaticJoint(body1, body2, x1, y1, x2, y2, ax, ay, collideConnected, referenceAngle) end

--- Creates a PulleyJoint to join two bodies to each other and the ground. The pulley joint simulates...
---@param body1 LovePhysicsBody
--- The first body to connect with a pulley joint.
---@param body2 LovePhysicsBody
--- The second body to connect with a pulley joint.
---@param gx1 number
--- The x coordinate of the first body's ground anchor.
---@param gy1 number
--- The y coordinate of the first body's ground anchor.
---@param gx2 number
--- The x coordinate of the second body's ground anchor.
---@param gy2 number
--- The y coordinate of the second body's ground anchor.
---@param x1 number
--- The x coordinate of the pulley joint anchor in the first body.
---@param y1 number
--- The y coordinate of the pulley joint anchor in the first body.
---@param x2 number
--- The x coordinate of the pulley joint anchor in the second body.
---@param y2 number
--- The y coordinate of the pulley joint anchor in the second body.
---@param ratio? number
--- The joint ratio.
---@param collideConnected? boolean
--- Specifies whether the two bodies should collide with each other.
---@return LovePhysicsPulleyJoint
--- The new pulley joint.
function love.physics.newPulleyJoint(body1, body2, gx1, gy1, gx2, gy2, x1, y1, x2, y2, ratio, collideConnected) end

--- Shorthand for creating rectangular PolygonShapes. By default, the local origin is located at the ...
---@param x number
--- The offset along the x-axis.
---@param y number
--- The offset along the y-axis.
---@param width number
--- The width of the rectangle.
---@param height number
--- The height of the rectangle.
---@param angle? number
--- The initial angle of the rectangle.
---@overload fun(number, number)
---@return LovePhysicsPolygonShape
--- A new PolygonShape.
function love.physics.newRectangleShape(x, y, width, height, angle) end

--- Creates a pivot joint between two bodies. This joint connects two bodies to a point around which ...
---@param body1 LovePhysicsBody
--- The first body.
---@param body2 LovePhysicsBody
--- The second body.
---@param x1 number
--- The x position of the first connecting point.
---@param y1 number
--- The y position of the first connecting point.
---@param x2 number
--- The x position of the second connecting point.
---@param y2 number
--- The y position of the second connecting point.
---@param collideConnected? boolean
--- Specifies whether the two bodies should collide with each other.
---@param referenceAngle? number
--- The reference angle between body1 and body2, in radians.
---@overload fun(LovePhysicsBody, LovePhysicsBody, number, number, boolean?)
---@return LovePhysicsRevoluteJoint
--- The new revolute joint.
function love.physics.newRevoluteJoint(body1, body2, x1, y1, x2, y2, collideConnected, referenceAngle) end

--- Creates a joint between two bodies. Its only function is enforcing a max distance between these b...
---@param body1 LovePhysicsBody
--- The first body to attach to the joint.
---@param body2 LovePhysicsBody
--- The second body to attach to the joint.
---@param x1 number
--- The x position of the first anchor point.
---@param y1 number
--- The y position of the first anchor point.
---@param x2 number
--- The x position of the second anchor point.
---@param y2 number
--- The y position of the second anchor point.
---@param maxLength number
--- The maximum distance for the bodies.
---@param collideConnected? boolean
--- Specifies whether the two bodies should collide with each other.
---@return LovePhysicsRopeJoint
--- The new RopeJoint.
function love.physics.newRopeJoint(body1, body2, x1, y1, x2, y2, maxLength, collideConnected) end

--- Creates a constraint joint between two bodies. A WeldJoint essentially glues two bodies together....
---@param body1 LovePhysicsBody
--- The first body to attach to the joint.
---@param body2 LovePhysicsBody
--- The second body to attach to the joint.
---@param x1 number
--- The x position of the first anchor point (world space).
---@param y1 number
--- The y position of the first anchor point (world space).
---@param x2 number
--- The x position of the second anchor point (world space).
---@param y2 number
--- The y position of the second anchor point (world space).
---@param collideConnected? boolean
--- Specifies whether the two bodies should collide with each other.
---@param referenceAngle? number
--- The reference angle between body1 and body2, in radians.
---@overload fun(LovePhysicsBody, LovePhysicsBody, number, number, boolean?)
---@overload fun(LovePhysicsBody, LovePhysicsBody, number, number, number, number, boolean?)
---@return LovePhysicsWeldJoint
--- The new WeldJoint.
function love.physics.newWeldJoint(body1, body2, x1, y1, x2, y2, collideConnected, referenceAngle) end

--- Creates a wheel joint.
---@param body1 LovePhysicsBody
--- The first body.
---@param body2 LovePhysicsBody
--- The second body.
---@param x1 number
--- The x position of the first anchor point.
---@param y1 number
--- The y position of the first anchor point.
---@param x2 number
--- The x position of the second anchor point.
---@param y2 number
--- The y position of the second anchor point.
---@param ax number
--- The x position of the axis unit vector.
---@param ay number
--- The y position of the axis unit vector.
---@param collideConnected? boolean
--- Specifies whether the two bodies should collide with each other.
---@overload fun(LovePhysicsBody, LovePhysicsBody, number, number, number, number, boolean?)
---@return LovePhysicsWheelJoint
--- The new WheelJoint.
function love.physics.newWheelJoint(body1, body2, x1, y1, x2, y2, ax, ay, collideConnected) end

--- Creates a new World.
---@param xg? number
--- The x component of gravity.
---@param yg? number
--- The y component of gravity.
---@param sleep? boolean
--- Whether the bodies in this world are allowed to sleep.
---@return LovePhysicsWorld
--- A brave new World.
function love.physics.newWorld(xg, yg, sleep) end

--- Sets the pixels to meter scale factor. All coordinates in the physics module are divided by this ...
---@param scale number
--- The scale factor as an integer.
function love.physics.setMeter(scale) end

--- ------------------------------------------------------------
--- love.sound
--- This module is responsible for decoding sound files. It can't play the sounds, see love.audio for...
---@class love.sound
love.sound = {}

--- An object which can gradually decode a sound file.
---@class LoveSoundDecoder
LoveSoundDecoder = {}

--- Creates a new copy of current decoder. The new decoder will start decoding from the beginning of ...
---@return LoveSoundDecoder
--- New copy of the decoder.
function LoveSoundDecoder:clone() end

--- Decodes the audio and returns a SoundData object containing the decoded audio data.
---@return LoveSoundSoundData
--- Decoded audio data.
function LoveSoundDecoder:decode() end

--- Returns the number of bits per sample.
---@return number
--- Either 8, or 16.
function LoveSoundDecoder:getBitDepth() end

--- Returns the number of channels in the stream.
---@return number
--- 1 for mono, 2 for stereo.
function LoveSoundDecoder:getChannelCount() end

--- Gets the duration of the sound file. It may not always be sample-accurate, and it may return -1 i...
---@return number
--- The duration of the sound file in seconds, or -1 if it cannot be determined.
function LoveSoundDecoder:getDuration() end

--- Returns the sample rate of the Decoder.
---@return number
--- Number of samples per second.
function LoveSoundDecoder:getSampleRate() end

--- Sets the currently playing position of the Decoder.
---@param offset number
--- The position to seek to, in seconds.
function LoveSoundDecoder:seek(offset) end

--- Contains raw audio samples. You can not play SoundData back directly. You must wrap a Source obje...
---@class LoveSoundSoundData
--- (also inherits: Object)
LoveSoundSoundData = {}

--- Returns the number of bits per sample.
---@return number
--- Either 8, or 16.
function LoveSoundSoundData:getBitDepth() end

--- Returns the number of channels in the SoundData.
---@return number
--- 1 for mono, 2 for stereo.
function LoveSoundSoundData:getChannelCount() end

--- Gets the duration of the sound data.
---@return number
--- The duration of the sound data in seconds.
function LoveSoundSoundData:getDuration() end

--- Gets the value of the sample-point at the specified position. For stereo SoundData objects, the d...
---@param i number
--- An integer value specifying the position of the sample (starting at 0).
---@param channel number
--- The index of the channel to get within the given sample.
---@overload fun(number)
---@return number
--- The normalized samplepoint (range -1.0 to 1.0).
function LoveSoundSoundData:getSample(i, channel) end

--- Returns the number of samples per channel of the SoundData.
---@return number
--- Total number of samples.
function LoveSoundSoundData:getSampleCount() end

--- Returns the sample rate of the SoundData.
---@return number
--- Number of samples per second.
function LoveSoundSoundData:getSampleRate() end

--- Sets the value of the sample-point at the specified position. For stereo SoundData objects, the d...
---@param i number
--- An integer value specifying the position of the sample (starting at 0).
---@param channel number
--- The index of the channel to set within the given sample.
---@param sample number
--- The normalized samplepoint (range -1.0 to 1.0).
---@overload fun(number, number)
function LoveSoundSoundData:setSample(i, channel, sample) end

--- Attempts to find a decoder for the encoded sound data in the specified file.
---@param file LoveFilesystemFile
--- The file with encoded sound data.
---@param buffer? number
--- The size of each decoded chunk, in bytes.
---@return LoveSoundDecoder
--- A new Decoder object.
function love.sound.newDecoder(file, buffer) end

--- Creates new SoundData from a filepath, File, or Decoder. It's also possible to create SoundData w...
---@param samples number
--- Total number of samples.
---@param rate? number
--- Number of samples per second
---@param bits? number
--- Bits per sample (8 or 16).
---@param channels? number
--- Either 1 for mono or 2 for stereo.
---@overload fun(string)
---@return LoveSoundSoundData
--- A new SoundData object.
function love.sound.newSoundData(samples, rate, bits, channels) end

--- ------------------------------------------------------------
--- love.system
--- Provides access to information about the user's system.
---@class love.system
love.system = {}

--- The basic state of the system's power supply.
---@alias LoveSystemPowerState
---| 'unknown' # Cannot determine power status.
---| 'battery' # Not plugged in, running on a battery.
---| 'nobattery' # Plugged in, no battery available.
---| 'charging' # Plugged in, charging battery.
---| 'charged' # Plugged in, battery is fully charged.

--- Gets text from the clipboard.
---@return string
--- The text currently held in the system's clipboard.
function love.system.getClipboardText() end

--- Gets the current operating system. In general, LÖVE abstracts away the need to know the current ...
---@return string
--- The current operating system. 'OS X', 'Windows', 'Linux', 'Android' or 'iOS'.
function love.system.getOS() end

--- Gets information about the system's power supply.
---@return LoveSystemPowerState
--- The basic state of the power supply.
---@return number
--- Percentage of battery life left, between 0 and 100. nil if the value can't be...
---@return number
--- Seconds of battery life left. nil if the value can't be determined or there's...
function love.system.getPowerInfo() end

--- Gets the amount of logical processor in the system.
---@return number
--- Amount of logical processors.
function love.system.getProcessorCount() end

--- Gets whether another application on the system is playing music in the background. Currently this...
---@return boolean
--- True if the user is playing music in the background via another app, false ot...
function love.system.hasBackgroundMusic() end

--- Opens a URL with the user's web or file browser.
---@param url string
--- The URL to open. Must be formatted as a proper URL.
---@return boolean
--- Whether the URL was opened successfully.
function love.system.openURL(url) end

--- Puts text in the clipboard.
---@param text string
--- The new text to hold in the system's clipboard.
function love.system.setClipboardText(text) end

--- Causes the device to vibrate, if possible. Currently this will only work on Android and iOS devic...
---@param seconds? number
--- The duration to vibrate for. If called on an iOS device, it will always vibra...
function love.system.vibrate(seconds) end

--- ------------------------------------------------------------
--- love.thread
--- Allows you to work with threads. Threads are separate Lua environments, running in parallel to th...
---@class love.thread
love.thread = {}

--- An object which can be used to send and receive data between different threads.
---@class LoveThreadChannel
LoveThreadChannel = {}

--- Clears all the messages in the Channel queue.
function LoveThreadChannel:clear() end

--- Retrieves the value of a Channel message and removes it from the message queue. It waits until a ...
---@param timeout number
--- The maximum amount of time to wait.
---@overload fun()
---@return any
--- The contents of the message or nil if the timeout expired.
function LoveThreadChannel:demand(timeout) end

--- Retrieves the number of messages in the thread Channel queue.
---@return number
--- The number of messages in the queue.
function LoveThreadChannel:getCount() end

--- Gets whether a pushed value has been popped or otherwise removed from the Channel.
---@param id number
--- An id value previously returned by Channel:push.
---@return boolean
--- Whether the value represented by the id has been removed from the Channel via...
function LoveThreadChannel:hasRead(id) end

--- Retrieves the value of a Channel message, but leaves it in the queue. It returns nil if there's n...
---@return any
--- The contents of the message.
function LoveThreadChannel:peek() end

--- Executes the specified function atomically with respect to this Channel. Calling multiple methods...
---@param func function
--- The function to call, the form of function(channel, arg1, arg2, ...) end. The...
---@param ___ any
--- Additional arguments that the given function will receive when it is called.
---@return any
--- The first return value of the given function (if any.)
---@return any
--- Any other return values.
function LoveThreadChannel:performAtomic(func, ___) end

--- Retrieves the value of a Channel message and removes it from the message queue. It returns nil if...
---@return any
--- The contents of the message.
function LoveThreadChannel:pop() end

--- Send a message to the thread Channel. See Variant for the list of supported types.
---@param value any
--- The contents of the message.
---@return number
--- Identifier which can be supplied to Channel:hasRead
function LoveThreadChannel:push(value) end

--- Send a message to the thread Channel and wait for a thread to accept it. See Variant for the list...
---@param value any
--- The contents of the message.
---@param timeout number
--- The maximum amount of time to wait.
---@overload fun(any)
---@return boolean
--- Whether the message was successfully supplied before the timeout expired.
function LoveThreadChannel:supply(value, timeout) end

--- A Thread is a chunk of code that can run in parallel with other threads. Data can be sent between...
---@class LoveThreadThread
LoveThreadThread = {}

--- Retrieves the error string from the thread if it produced an error.
---@return string
--- The error message, or nil if the Thread has not caused an error.
function LoveThreadThread:getError() end

--- Returns whether the thread is currently running. Threads which are not running can be (re)started...
---@return boolean
--- True if the thread is running, false otherwise.
function LoveThreadThread:isRunning() end

--- Starts the thread. Beginning with version 0.9.0, threads can be restarted after they have complet...
---@param ___ any
--- A string, number, boolean, LÖVE object, or simple table.
---@overload fun()
function LoveThreadThread:start(___) end

--- Wait for a thread to finish. This call will block until the thread finishes.
function LoveThreadThread:wait() end

--- Creates or retrieves a named thread channel.
---@param name string
--- The name of the channel you want to create or retrieve.
---@return LoveThreadChannel
--- The Channel object associated with the name.
function love.thread.getChannel(name) end

--- Create a new unnamed thread channel. One use for them is to pass new unnamed channels to other th...
---@return LoveThreadChannel
--- The new Channel object.
function love.thread.newChannel() end

--- Creates a new Thread from a filename, string or FileData object containing Lua code.
---@param filename string
--- The name of the Lua file to use as the source.
---@return LoveThreadThread
--- A new Thread that has yet to be started.
function love.thread.newThread(filename) end

--- ------------------------------------------------------------
--- love.timer
--- Provides an interface to the user's clock.
---@class love.timer
love.timer = {}

--- Returns the average delta time (seconds per frame) over the last second.
---@return number
--- The average delta time over the last second.
function love.timer.getAverageDelta() end

--- Returns the time between the last two frames.
---@return number
--- The time passed (in seconds).
function love.timer.getDelta() end

--- Returns the current frames per second.
---@return number
--- The current FPS.
function love.timer.getFPS() end

--- Returns the value of a timer with an unspecified starting time. This function should only be used...
---@return number
--- The time in seconds. Given as a decimal, accurate to the microsecond.
function love.timer.getTime() end

--- Pauses the current thread for the specified amount of time.
---@param s number
--- Seconds to sleep for.
function love.timer.sleep(s) end

--- Measures the time between two frames. Calling this changes the return value of love.timer.getDelta.
---@return number
--- The time passed (in seconds).
function love.timer.step() end

--- ------------------------------------------------------------
--- love.touch
--- Provides an interface to touch-screen presses.
---@class love.touch
love.touch = {}

--- Gets the current position of the specified touch-press, in pixels.
---@param id any
--- [light userdata] The identifier of the touch-press. Use love.touch.getTouches, love.touchpress...
---@return number
--- The position along the x-axis of the touch-press inside the window, in pixels.
---@return number
--- The position along the y-axis of the touch-press inside the window, in pixels.
function love.touch.getPosition(id) end

--- Gets the current pressure of the specified touch-press.
---@param id any
--- [light userdata] The identifier of the touch-press. Use love.touch.getTouches, love.touchpress...
---@return number
--- The pressure of the touch-press. Most touch screens aren't pressure sensitive...
function love.touch.getPressure(id) end

--- Gets a list of all active touch-presses.
---@return table
--- A list of active touch-press id values, which can be used with love.touch.get...
function love.touch.getTouches() end

--- ------------------------------------------------------------
--- love.video
--- This module is responsible for decoding, controlling, and streaming video files. It can't draw th...
---@class love.video
love.video = {}

--- An object which decodes, streams, and controls Videos.
---@class LoveVideoVideoStream
LoveVideoVideoStream = {}

--- Gets the filename of the VideoStream.
---@return string
--- The filename of the VideoStream
function LoveVideoVideoStream:getFilename() end

--- Gets whether the VideoStream is playing.
---@return boolean
--- Whether the VideoStream is playing.
function LoveVideoVideoStream:isPlaying() end

--- Pauses the VideoStream.
function LoveVideoVideoStream:pause() end

--- Plays the VideoStream.
function LoveVideoVideoStream:play() end

--- Rewinds the VideoStream. Synonym to VideoStream:seek(0).
function LoveVideoVideoStream:rewind() end

--- Sets the current playback position of the VideoStream.
---@param offset number
--- The time in seconds since the beginning of the VideoStream.
function LoveVideoVideoStream:seek(offset) end

--- Gets the current playback position of the VideoStream.
---@return number
--- The number of seconds sionce the beginning of the VideoStream.
function LoveVideoVideoStream:tell() end

--- Creates a new VideoStream. Currently only Ogg Theora video files are supported. VideoStreams can'...
---@param filename string
--- The file path to the Ogg Theora video file.
---@return LoveVideoVideoStream
--- A new VideoStream.
function love.video.newVideoStream(filename) end

--- ------------------------------------------------------------
--- love.window
--- Provides an interface for modifying and retrieving information about the program's window.
---@class love.window
love.window = {}

--- Types of device display orientation.
---@alias LoveWindowDisplayOrientation
---| 'unknown' # Orientation cannot be determined.
---| 'landscape' # Landscape orientation.
---| 'landscapeflipped' # Landscape orientation (flipped).
---| 'portrait' # Portrait orientation.
---| 'portraitflipped' # Portrait orientation (flipped).

--- Types of fullscreen modes.
---@alias LoveWindowFullscreenType
---| 'desktop' # Sometimes known as borderless fullscreen windowed mode. A borderles...
---| 'exclusive' # Standard exclusive-fullscreen mode. Changes the display mode (actua...
---| 'normal' # Standard exclusive-fullscreen mode. Changes the display mode (actua...

--- Types of message box dialogs. Different types may have slightly different looks.
---@alias LoveWindowMessageBoxType
---| 'info' # Informational dialog.
---| 'warning' # Warning dialog.
---| 'error' # Error dialog.

--- Closes the window. It can be reopened with love.window.setMode.
function love.window.close() end

--- Converts a number from pixels to density-independent units. The pixel density inside the window m...
---@param px number
--- The x-axis value of a coordinate in pixels.
---@param py number
--- The y-axis value of a coordinate in pixels.
---@overload fun(number)
---@return number
--- The converted x-axis value of the coordinate, in density-independent units.
---@return number
--- The converted y-axis value of the coordinate, in density-independent units.
function love.window.fromPixels(px, py) end

--- Gets the DPI scale factor associated with the window. The pixel density inside the window might b...
---@return number
--- The pixel scale factor associated with the window.
function love.window.getDPIScale() end

--- Gets the width and height of the desktop.
---@param displayindex? number
--- The index of the display, if multiple monitors are available.
---@return number
--- The width of the desktop.
---@return number
--- The height of the desktop.
function love.window.getDesktopDimensions(displayindex) end

--- Gets the number of connected monitors.
---@return number
--- The number of currently connected displays.
function love.window.getDisplayCount() end

--- Gets the name of a display.
---@param displayindex? number
--- The index of the display to get the name of.
---@return string
--- The name of the specified display.
function love.window.getDisplayName(displayindex) end

--- Gets current device display orientation.
---@param displayindex? number
--- Display index to get its display orientation, or nil for default display index.
---@return LoveWindowDisplayOrientation
--- Current device display orientation.
function love.window.getDisplayOrientation(displayindex) end

--- Gets whether the window is fullscreen.
---@return boolean
--- True if the window is fullscreen, false otherwise.
---@return LoveWindowFullscreenType
--- The type of fullscreen mode used.
function love.window.getFullscreen() end

--- Gets a list of supported fullscreen modes.
---@param displayindex? number
--- The index of the display, if multiple monitors are available.
---@return table
--- A table of width/height pairs. (Note that this may not be in order.)
function love.window.getFullscreenModes(displayindex) end

--- Gets the window icon.
---@return LoveImageImageData
--- The window icon imagedata, or nil if no icon has been set with love.window.se...
function love.window.getIcon() end

--- Gets the display mode and properties of the window.
---@return number
--- Window width.
---@return number
--- Window height.
---@return table
--- Table with the window properties:
function love.window.getMode() end

--- Gets the position of the window on the screen. The window position is in the coordinate space of ...
---@return number
--- The x-coordinate of the window's position.
---@return number
--- The y-coordinate of the window's position.
---@return number
--- The index of the display that the window is in.
function love.window.getPosition() end

--- Gets area inside the window which is known to be unobstructed by a system title bar, the iPhone X...
---@return number
--- Starting position of safe area (x-axis).
---@return number
--- Starting position of safe area (y-axis).
---@return number
--- Width of safe area.
---@return number
--- Height of safe area.
function love.window.getSafeArea() end

--- Gets the window title.
---@return string
--- The current window title.
function love.window.getTitle() end

--- Gets current vertical synchronization (vsync).
---@return number
--- Current vsync status. 1 if enabled, 0 if disabled, and -1 for adaptive vsync.
function love.window.getVSync() end

--- Checks if the game window has keyboard focus.
---@return boolean
--- True if the window has the focus or false if not.
function love.window.hasFocus() end

--- Checks if the game window has mouse focus.
---@return boolean
--- True if the window has mouse focus or false if not.
function love.window.hasMouseFocus() end

--- Gets whether the display is allowed to sleep while the program is running. Display sleep is disab...
---@return boolean
--- True if system display sleep is enabled / allowed, false otherwise.
function love.window.isDisplaySleepEnabled() end

--- Gets whether the Window is currently maximized. The window can be maximized if it is not fullscre...
---@return boolean
--- True if the window is currently maximized in windowed mode, false otherwise.
function love.window.isMaximized() end

--- Gets whether the Window is currently minimized.
---@return boolean
--- True if the window is currently minimized, false otherwise.
function love.window.isMinimized() end

--- Checks if the window is open.
---@return boolean
--- True if the window is open, false otherwise.
function love.window.isOpen() end

--- Checks if the game window is visible. The window is considered visible if it's not minimized and ...
---@return boolean
--- True if the window is visible or false if not.
function love.window.isVisible() end

--- Makes the window as large as possible. This function has no effect if the window isn't resizable,...
function love.window.maximize() end

--- Minimizes the window to the system's task bar / dock.
function love.window.minimize() end

--- Causes the window to request the attention of the user if it is not in the foreground. In Windows...
---@param continuous? boolean
--- Whether to continuously request attention until the window becomes active, or...
function love.window.requestAttention(continuous) end

--- Restores the size and position of the window if it was minimized or maximized.
function love.window.restore() end

--- Sets whether the display is allowed to sleep while the program is running. Display sleep is disab...
---@param enable boolean
--- True to enable system display sleep, false to disable it.
function love.window.setDisplaySleepEnabled(enable) end

--- Enters or exits fullscreen. The display to use when entering fullscreen is chosen based on which ...
---@param fullscreen boolean
--- Whether to enter or exit fullscreen mode.
---@param fstype LoveWindowFullscreenType
--- The type of fullscreen mode to use.
---@overload fun(boolean)
---@return boolean
--- True if an attempt to enter fullscreen was successful, false otherwise.
function love.window.setFullscreen(fullscreen, fstype) end

--- Sets the window icon until the game is quit. Not all operating systems support very large icon im...
---@param imagedata LoveImageImageData
--- The window icon image.
---@return boolean
--- Whether the icon has been set successfully.
function love.window.setIcon(imagedata) end

--- Sets the display mode and properties of the window. If width or height is 0, setMode will use the...
---@param width number
--- Display width.
---@param height number
--- Display height.
---@param flags table
--- The flags table with the options:
---@return boolean
--- True if successful, false otherwise.
function love.window.setMode(width, height, flags) end

--- Sets the position of the window on the screen. The window position is in the coordinate space of ...
---@param x number
--- The x-coordinate of the window's position.
---@param y number
--- The y-coordinate of the window's position.
---@param displayindex? number
--- The index of the display that the new window position is relative to.
function love.window.setPosition(x, y, displayindex) end

--- Sets the window title.
---@param title string
--- The new window title.
function love.window.setTitle(title) end

--- Sets vertical synchronization mode.
---@param vsync number
--- VSync number: 1 to enable, 0 to disable, and -1 for adaptive vsync.
function love.window.setVSync(vsync) end

--- Displays a message box dialog above the love window. The message box contains a title, optional t...
---@param title string
--- The title of the message box.
---@param message string
--- The text inside the message box.
---@param buttonlist table
--- A table containing a list of button names to show. The table can also contain...
---@param type? LoveWindowMessageBoxType
--- The type of the message box.
---@param attachtowindow? boolean
--- Whether the message box should be attached to the love window or free-floating.
---@overload fun(string, string, LoveWindowMessageBoxType?, boolean?)
---@return number
--- The index of the button pressed by the user. May be 0 if the message box dial...
function love.window.showMessageBox(title, message, buttonlist, type, attachtowindow) end

--- Converts a number from density-independent units to pixels. The pixel density inside the window m...
---@param x number
--- The x-axis value of a coordinate in density-independent units to convert to p...
---@param y number
--- The y-axis value of a coordinate in density-independent units to convert to p...
---@overload fun(number)
---@return number
--- The converted x-axis value of the coordinate, in pixels.
---@return number
--- The converted y-axis value of the coordinate, in pixels.
function love.window.toPixels(x, y) end

--- Sets the display mode and properties of the window, without modifying unspecified properties. If ...
---@param width number
--- Window width.
---@param height number
--- Window height.
---@param settings table
--- The settings table with the following optional fields. Any field not filled i...
---@return boolean
--- True if successful, false otherwise.
function love.window.updateMode(width, height, settings) end
