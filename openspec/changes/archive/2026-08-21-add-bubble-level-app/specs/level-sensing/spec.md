## Purpose

Turns raw Android motion-sensor hardware output into stable, calibrated tilt angles and a device posture that the rest of the app can present, without requiring permissions or a network connection.

## ADDED Requirements

### Requirement: Tilt derived from device motion hardware

The app SHALL derive device tilt from the handset's built-in motion sensors, preferring a hardware- or system-fused gravity signal and falling back to the raw accelerometer when no gravity signal is available. The app SHALL NOT request any runtime permission and SHALL NOT use the network to determine tilt.

#### Scenario: Gravity signal available

- **WHEN** the device exposes a gravity sensor
- **THEN** tilt is computed from the gravity signal
- **AND** no permission prompt is shown to the user

#### Scenario: Only accelerometer available

- **WHEN** the device exposes no gravity sensor but does expose an accelerometer
- **THEN** tilt is computed from the accelerometer signal
- **AND** the app functions identically from the user's point of view

#### Scenario: No usable sensor

- **WHEN** the device exposes neither a gravity sensor nor an accelerometer
- **THEN** the app shows a message stating that the device has no compatible tilt sensor
- **AND** no bubble or angle readout is displayed

### Requirement: Pitch and roll angle output

The app SHALL express tilt as a pitch angle and a roll angle in degrees, each relative to the horizontal plane, resolved to 0.1 degrees. Pitch SHALL be positive when the top edge of the device is raised, and roll SHALL be positive when the right edge of the device is raised.

#### Scenario: Device resting on a level surface

- **WHEN** the device lies face up on a surface that is level within 0.05 degrees
- **AND** no calibration offset is applied
- **THEN** the reported pitch and roll are each within 1.0 degree of zero

#### Scenario: Known tilt about one axis

- **WHEN** the device lies face up on a surface raised at its top edge by a known angle
- **THEN** the reported pitch is positive and within 1.0 degree of that known angle
- **AND** the reported roll remains within 1.0 degree of zero

### Requirement: Smoothed and responsive readings

The app SHALL smooth sensor noise so that a stationary device produces a visually steady reading, while remaining responsive to real movement. A stationary device SHALL produce readings that vary by no more than 0.2 degrees between successive updates, and after the device is moved to a new fixed tilt the reading SHALL settle to within 0.2 degrees of the new value in no more than 500 milliseconds. Angle updates SHALL be delivered to the display at a rate of at least 20 per second.

#### Scenario: Device left untouched

- **WHEN** the device rests untouched on a fixed surface for 10 seconds
- **THEN** every reported angle is within 0.2 degrees of the previous reported angle

#### Scenario: Device moved to a new tilt

- **WHEN** the device is moved from one fixed tilt to another
- **THEN** within 500 milliseconds the reported angles are within 0.2 degrees of the new tilt's true angles

### Requirement: Posture classification

The app SHALL classify the device as either flat, when its screen faces predominantly up or down, or upright, when the device is held on edge or vertically. Classification SHALL switch to upright when the device is tilted more than 60 degrees from horizontal and back to flat only when it returns to within 50 degrees of horizontal, so that a device held near the boundary does not oscillate between postures.

#### Scenario: Device lying on a table

- **WHEN** the device lies face up, tilted less than 50 degrees from horizontal
- **THEN** the posture is flat

#### Scenario: Device stood on its edge

- **WHEN** the device is tilted more than 60 degrees from horizontal
- **THEN** the posture is upright

#### Scenario: Device held near the posture boundary

- **WHEN** the posture is upright and the device is slowly returned toward horizontal
- **THEN** the posture stays upright until the device is within 50 degrees of horizontal
- **AND** the posture changes at most once during that movement

### Requirement: Sensor use limited to the foreground

The app SHALL consume sensor data only while it is visible to the user, and SHALL stop consuming sensor data when it is backgrounded or its screen is otherwise not shown. Sensor delivery SHALL resume automatically when the app returns to the foreground.

#### Scenario: App sent to the background

- **WHEN** the user leaves the app
- **THEN** the app stops receiving sensor updates

#### Scenario: App brought back to the foreground

- **WHEN** the user returns to the app
- **THEN** sensor updates resume
- **AND** a live reading is displayed within 500 milliseconds without user interaction
