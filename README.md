# STOP Sign Detection in MATLAB

A team project for a digital image processing course. The detector uses classical image processing to locate a STOP sign, estimate its eight vertices, and visualize an NCC-based matching score.

The repository is based on the final submission in `Project1_Submission/source_code`. The report, slides, presentation script, and source-code description are available in [docs/](docs/). Team contributions are recorded in the report.

## Method

1. Extract red regions with HSV/RGB thresholds and morphological operations.
2. Propose octagons using convex hulls, shape tests, and geometric constraints.
3. Rectify each candidate to the template coordinate system.
4. Compute normalized cross-correlation (NCC) over the sign face and central text region, allowing small shifts and scale changes.
5. Select the best candidate and apply the regular or auxiliary acceptance rule.

## Results

![STOP sign detection example](examples/result_1.png)

[Result figures](examples/) · [Measured scores](examples/summary.csv) · [Course report](docs/report.docx) · [Presentation](docs/presentation.pptx) · [Source-code description](docs/source-code-description.pdf)

The English figures were regenerated in MATLAB from the final implementation. The current run reproduces the archived final scores. The report distinguishes this run from earlier development observations; the original English slides and presentation script preserve their historical context.

The course images were used during development. Results on these images describe the implementation's behavior on the supplied examples and are not an independent measure of generalization. The detector returns one best candidate per image, including scenes with multiple STOP signs.

## Requirements and usage

- MATLAB with Image Processing Toolbox.
- A MATLAB version that supports `fitgeotform2d`. The minimum supported release has not been established.
- Keep the source files, template, vertex annotations, and `test images/` in their existing relative locations.

Set MATLAB's current folder to the repository root and run:

```matlab
main_stop_detection
```

The script reads the images in `test images/` and writes new figures to `results/`. Git ignores this runtime output directory. Figures selected for the repository are stored separately in `examples/`.

The repository includes `template_stop.jpg` and `template_points.mat`. To annotate a different template, run `manual_template_points` from the repository root and click its eight corners in order. This replaces the vertex annotation file.

## Main files

| File | Purpose |
|---|---|
| `main_stop_detection.m` | Batch entry point, parameters, and visualization |
| `red_segmentation.m` | Red-region segmentation |
| `find_octagon_candidates.m` | Octagon proposal and filtering |
| `detect_stop_sign.m` | Candidate rectification, scoring, and selection |
| `rectify_octagon.m` | Projective transformation |
| `compute_ncc_with_mask.m` | Masked face/text correlation |
| `manual_template_points.m` | Template vertex annotation |
| `extract_octagon_vertices.m` | Retained auxiliary function |

## Acceptance rules and limitations

The regular rule accepts a combined matching score of at least 0.30. The auxiliary rule requires all three conditions: combined score ≥ 0.25, text-region NCC ≥ 0.25, and internal red fraction ≥ 0.60. NCC is a similarity score, not a calibrated probability.

The thresholds and geometric rules were developed on a limited set of course images. Clutter, illumination, occlusion, and lettering differences can affect detection. See the report for failure cases, development history, and limits of the evaluation.

## Project materials

This repository archives course work and does not include a separate open-source license. Input images, team documents, and third-party materials remain subject to their respective rights. See [ARCHIVE_NOTES.md](ARCHIVE_NOTES.md) for the archive history.
