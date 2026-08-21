## Purpose

Lets the user cancel out sensor bias and case asymmetry by declaring a surface to be level, and keeps that zero point across app launches so the level stays trustworthy over time.

## ADDED Requirements

### Requirement: Capture a zero point

The app SHALL provide a control that captures the current raw tilt as the zero point for the current posture. After capture, the displayed angles for that posture SHALL read zero while the device remains undisturbed.

#### Scenario: Calibrating on a known-flat surface

- **WHEN** the device rests flat on a surface the user considers level and the user activates the calibrate control
- **THEN** the displayed pitch and roll both read 0.0 degrees
- **AND** the bubble is centered

#### Scenario: Measuring after calibration

- **WHEN** a calibration has been captured and the device is then tilted by a known angle
- **THEN** the displayed angle equals that known angle within 1.0 degree

### Requirement: Calibration offsets are applied per posture

The app SHALL store a separate zero point for the flat posture and for the upright posture, and SHALL apply only the offset belonging to the current posture. Capturing a zero point in one posture SHALL NOT alter the other posture's zero point.

#### Scenario: Calibrating flat then measuring upright

- **WHEN** the user calibrates in flat posture and then holds the device upright
- **THEN** the upright reading uses the upright zero point
- **AND** the flat zero point is unchanged

### Requirement: Calibration persists across launches

The app SHALL store captured zero points on the device and SHALL reapply them automatically on the next launch, with no user action required. Stored zero points SHALL survive the app being closed or the device being restarted.

#### Scenario: Reopening the app

- **WHEN** the user calibrates, closes the app, and reopens it on the same surface
- **THEN** the displayed angles still read 0.0 degrees

#### Scenario: First launch after install

- **WHEN** the app is launched with no stored calibration
- **THEN** readings are shown with a zero offset and no error is displayed

### Requirement: Reset to factory zero

The app SHALL provide a control that clears all stored zero points and returns the app to uncalibrated readings. The control SHALL confirm with the user before clearing, and its effect SHALL be immediate and persistent.

#### Scenario: Clearing calibration

- **WHEN** the user activates the reset control and confirms
- **THEN** displayed angles are computed with no offset
- **AND** no stored zero point remains after the app is relaunched

#### Scenario: Declining the confirmation

- **WHEN** the user activates the reset control and declines the confirmation
- **THEN** the stored zero points are left unchanged

### Requirement: Implausible calibration is rejected

The app SHALL refuse to capture a zero point when the raw tilt exceeds 10 degrees from the nominal orientation for the current posture, since such a capture would come from a surface that is not usable as a reference. The app SHALL tell the user why the capture was refused and SHALL leave any existing zero point unchanged.

#### Scenario: Calibrating on a steeply tilted surface

- **WHEN** the raw tilt is more than 10 degrees from nominal and the user activates the calibrate control
- **THEN** the app shows a message explaining that the surface is too far from level to use as a reference
- **AND** the previously stored zero point is unchanged

#### Scenario: Calibrating within the allowed range

- **WHEN** the raw tilt is within 10 degrees of nominal and the user activates the calibrate control
- **THEN** the zero point is captured
