---@ meta

-- Mixer Enums ---------------------------------------------------------------------------


---@enum (key) MultiChannelMode
MultiChannelMode = {
  Mono = 1,
  Stereo = 2,
  Multi = 3,
}

---@enum (key) AutomixerOutuptType
AutomixerOutuptType = {
  MixOnly = 1,
  ChannelOnly = 2,
  MixAndChannel = 3,
}

---@enum (key) PanNormalizationMode
PanNormalizationMode = {
  ConstantVoltage = 1,
  ConstantPower = 2,
}

---@enum (key) PanStrategy
PanStrategy = {
  NoPanControls = 0,
  PanPerInput = 1,
  PanPerCrosspoint = 2,
}

---@enum (key) CrosspointGainType
CrosspointGainType = {
  Standard = 0,
  XFade3dB = 1,
  XFade6dB = 2,
}


---@enum (key) DelayMixGainType
DelayMixGainType = {
  Standard = 0,
  Linear = 1,
  XFade3dB = 2,
  XFade6dB = 3,
}


---@enum (key) GainComponentStepMode
GainComponentStepMode = {
  Continuous = 0,
  Discrete = 1,
}

---@enum (key) RouterSelectionControlType
RouterSelectionControlType = {
  Knobs = 0,
  ComboBoxes = 1,
  CrosspointButtons = 2,
}


---@enum (key) RouterSelectionMode
RouterSelectionMode = {
  Source = 0,
  Destination = 1,
}



-- Filter Enums ---------------------------------------------------------------------------


---@enum (key) FilterOrder
FilterOrder = {
  First = 1,
  Second = 2,
}


---@enum (key) ResponsePanelSizeType
ResponsePanelSizeType = {
  Small = 1,
  Medium = 2,
  Large = 3,
}


---@enum (key) FilterSlopeType
FilterSlopeType = {
  Slope6dBPerOctave = 6,
  Slope12dBPerOctave = 12,
}

---@enum (key) FIRTransitionBandwidthType
FIRTransitionBandwidthType = {
  OneOctave = 1,
  HalfOctave = 0.5,
  QuarterOctave = 0.25,
}

---@enum (key) FlattopTransitionBandwidthType
FlattopTransitionBandwidthType = {
  OneOctave = 1,
  HalfOctave = 0.5,
  ThirdOctave = 1.0/3.0,
  SixthOctave = 1.0/6.0,
  TwelfthOctave = 1.0/12.0,
}


---@enum (key) PhaseResponseType
PhaseResponseType = {
  Minimum = 0,
  Linear = 1,
}


---@enum (key) BandwidthOrQFactorType
BandwidthOrQFactorType = {
  Bandwidth = 0,
  QFactor = 1,
  Both = 2,
}


---@enum (key) WeightingType
WeightingType = {
  A = 1,
  C = 2,
}
