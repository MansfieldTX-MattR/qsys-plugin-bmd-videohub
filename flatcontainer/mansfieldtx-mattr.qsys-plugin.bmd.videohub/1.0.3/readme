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

#### Control Pins


| Name                  | Description                             | Direction       | Type    |
| ---                   | ---                                     | ---             | ---     |
| **Crosspoints *n***   | The current input routed to output *n*  | Input / Output  | Integer |
| **InputLabels *n***   | Label text for input *n*                | Input / Output  | String  |
| **OutputLabels *n***  | Label text for output *n*               | Input / Output  | String  |
| **ControlLockout**    | Enable or disable control lockout       | Input           | Boolean |
| **Status**            | The device / connection status          | Output          | Status  |
| **DeviceId**          | The detected device's ID                | Output          | String  |
| **DeviceModel**       | The detected device's model             | Output          | String  |
| **DeviceName**        | The detected device's name              | Output          | String  |
| **NumInputs**         | The detected number of inputs           | Output          | Integer |
| **NumOutputs**        | The detected number of outputs          | Output          | Integer |



## Known Issues

- Snapshot and restore functionality is not yet implemented.
- Not tested with all Videohub models, so compatibility may vary.


## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
