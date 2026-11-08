# Sound effects

- guild_wood.wav: Kenney, Impact Sounds, impactWood_light_001.ogg, CC0 1.0. Trimmed and volume-adjusted. https://kenney.nl/assets/impact-sounds
- guild_gold.wav: Amarikah (with pennomi), Sack of Gold, gold_sack.wav, CC0 1.0. Edited and volume-adjusted. https://opengameart.org/content/sack-of-gold

These files are normalized to the same full-clip RMS without clipping.

- guild_reveal_normal.wav and guild_reveal_hard.wav: synthesized using analysis-by-synthesis from a reference preview that itself included edited excerpts from third-party videos (https://youtu.be/tAgZOmPV_GE and https://youtu.be/SwrHkBDuwFE). The resulting files contain no direct reference audio samples, but the rights implications of their derivation and similarity have not been independently cleared. They require a rights review before release or distribution.

The reveal effects are adjusted to the existing full-clip RMS and converted to 32 kHz stereo PCM, with each decoded file below 1 MB for Android SoundPool. All effects are bundled as Android raw resources and respect the effects-volume setting. No sound is assigned to closing the scroll or to buying, placing, or removing decorations.
