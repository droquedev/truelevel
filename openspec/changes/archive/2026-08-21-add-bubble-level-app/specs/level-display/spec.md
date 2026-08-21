## Purpose

Presents tilt to the user as a spirit-level bubble with a numeric readout, choosing the appropriate vial for how the device is being held, and keeps the app usable as a hands-free measuring tool.

## ADDED Requirements

### Requirement: Two-axis bubble when the device is flat

While the device posture is flat, the app SHALL display a circular vial containing a bubble whose displacement from the center represents pitch and roll simultaneously. The bubble SHALL move away from the raised side, its displacement SHALL be proportional to the tilt angle up to a full-scale tilt of 10 degrees, and it SHALL be clamped to the inner edge of the vial beyond full scale.

#### Scenario: Flat and level

- **WHEN** the posture is flat and both calibrated angles are zero
- **THEN** the bubble is centered in the circular vial

#### Scenario: One corner raised

- **WHEN** the posture is flat and the device is tilted so that its top-right corner is raised
- **THEN** the bubble moves toward the bottom-left of the vial

#### Scenario: Tilt beyond full scale

- **WHEN** the posture is flat and the tilt exceeds 10 degrees on an axis
- **THEN** the bubble is drawn touching the inner edge of the vial and does not leave it

### Requirement: Single-axis bubble when the device is upright

While the device posture is upright, the app SHALL display an elongated vial containing a bubble that represents rotation about the single axis relevant to a device held on edge, with the same 10-degree full-scale range and edge clamping as the flat vial.

#### Scenario: Upright and plumb

- **WHEN** the posture is upright and the calibrated angle for that axis is zero
- **THEN** the bubble is centered between the vial's two index marks

#### Scenario: Upright and tilted

- **WHEN** the posture is upright and the device leans to the right
- **THEN** the bubble moves toward the left end of the vial

### Requirement: Automatic switching between vials

The app SHALL switch between the two-axis and single-axis vials automatically based on the reported posture, with no control for the user to operate. The switch SHALL be animated so the display does not jump abruptly.

#### Scenario: Device lifted from a table to vertical

- **WHEN** the device is lifted from lying flat to being held upright
- **THEN** the display transitions from the circular vial to the elongated vial without user input

#### Scenario: Device laid back down

- **WHEN** the device is laid back down flat
- **THEN** the display transitions back to the circular vial

### Requirement: Numeric angle readout

The app SHALL display the calibrated tilt numerically in degrees to one decimal place, alongside the bubble. In flat posture both the pitch and roll values SHALL be shown; in upright posture the single relevant angle SHALL be shown. Values SHALL be shown with a sign or directional label so the user can tell which way the device is tilted.

#### Scenario: Flat with a tilt on both axes

- **WHEN** the posture is flat and the device is tilted on both axes
- **THEN** two angle values are shown, each with one decimal place

#### Scenario: Upright

- **WHEN** the posture is upright
- **THEN** exactly one angle value is shown, with one decimal place

### Requirement: Level indication

The app SHALL indicate when the surface is level. A reading SHALL be treated as level when every displayed angle is within 0.2 degrees of zero. While level, the app SHALL change the appearance of the vial and readout so the state is recognizable at a glance and without relying on color alone.

#### Scenario: Surface is level

- **WHEN** all displayed angles are within 0.2 degrees of zero
- **THEN** the vial and readout switch to their level appearance

#### Scenario: Surface leaves level

- **WHEN** a displayed angle moves beyond 0.2 degrees from zero
- **THEN** the level appearance is removed

### Requirement: Hands-free readability

While the app is in the foreground, the app SHALL keep the screen on and SHALL keep the interface in portrait orientation, so that a device placed on a surface stays readable and does not re-orient as it is tilted. Normal screen timeout behavior SHALL be restored when the app leaves the foreground.

#### Scenario: Device left on a surface

- **WHEN** the app is in the foreground and untouched past the system screen timeout
- **THEN** the screen remains on and the reading stays visible

#### Scenario: Device rotated while measuring

- **WHEN** the device is rotated or tilted while the app is in the foreground
- **THEN** the interface stays in portrait orientation

#### Scenario: User leaves the app

- **WHEN** the app leaves the foreground
- **THEN** the system's normal screen timeout applies again

### Requirement: Ad-free and offline operation

The app SHALL contain no advertising, no analytics, and no telemetry, and SHALL make no network requests. The installed application SHALL declare no network permission.

#### Scenario: Running with no connectivity

- **WHEN** the device has no network connection
- **THEN** every feature of the app works exactly as it does when connected

#### Scenario: Inspecting the installed app

- **WHEN** the built application's manifest is inspected
- **THEN** it declares no internet permission
- **AND** no advertising or analytics component is present
