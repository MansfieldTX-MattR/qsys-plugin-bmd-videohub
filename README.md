# qsys-plugin-bmd-videohub

A Q-SYS plugin for controlling Blackmagic Design Videohub matrix switchers.

## Project Links

<dl>
  <dt>Source Code</dt>
  <dd>https://github.com/MansfieldTX-MattR/qsys-plugin-bmd-videohub</dd>

  <dt>Downloads (qplug files)</dt>
  <dd>https://github.com/MansfieldTX-MattR/qsys-plugin-bmd-videohub/releases</dd>
</dl>


## Features


- Routing control and monitoring
- Label control and monitoring (for both inputs and outputs)
- Support for multiple Videohub models
  - Tested with Smart Videohub 12x12 Clean Switch
- Control lockout mode to act as a "read-only" interface if desired
- Real-time status updates
- Status Monitoring support (for use with Q-SYS Reflect, etc.)


## Usage

### Setup

When you first add the plugin component, set the "Max Input Count" and "Max Output Count" properties to match your Videohub model. For example, for a Smart Videohub 12x12, set both to 12.

Once the design is running (or in emulation mode), configure the "IP Address" and "Port" in the "Setup" page. The default port  (9990) should already be correct in most situations.


### Control

Use the "Route" page to control routing. The layout is similar to the built-in Q-SYS routing matrix, so it should be familiar to users of that component.

Use the "Input Labels" and "Output Labels" pages to control the labels for inputs and outputs, respectively. You can set the label text and also monitor changes made directly on the Videohub.

Control Pins are provided for:

- `Crosspoints`
  - One pin per output, with the input number as the value
  - Both input and output pins are provided for control and monitoring
- `InputLabels`
  - One pin per input, with the label text as the value
  - Both input and output pins are provided for control and monitoring
- `OutputLabels`
  - One pin per output, with the label text as the value
  - Both input and output pins are provided for control and monitoring
- `ControlLockout`
  - One pin, with a boolean value to enable/disable control lockout
  - This is an input pin only
- `Status`
  - One pin, using the standard Q-SYS status pin format
  - This is an output pin only
- `DeviceId`
  - One pin, with the detected device ID as the value
  - This is an output pin only
- `DeviceModel`
  - One pin, with the detected device model as the value
  - This is an output pin only
- `DeviceName`
  - One pin, with the detected device name as the value
  - This is an output pin only
- `NumInputs`
  - One pin, with the detected number of inputs as the value
  - This is an output pin only
- `NumOutputs`
  - One pin, with the detected number of outputs as the value
  - This is an output pin only


## Known Issues

- Snapshot and restore functionality is not yet implemented.
- Not tested with all Videohub models, so compatibility may vary.


## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
