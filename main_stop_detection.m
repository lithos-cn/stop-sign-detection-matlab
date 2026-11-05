% MAIN_STOP_DETECTION Detect STOP signs and save result figures.
clear; clc; close all;

%% Paths
% Keep functions, the template, and template_points.mat in this folder.
% Read test images from "test images" and save figures to "results".
base_dir = fileparts(mfilename('fullpath'));
if isempty(base_dir)
    error('Cannot locate the script directory. Save main_stop_detection.m before running.');
end
addpath(base_dir);
img_folder    = fullfile(base_dir, 'test images');
template_path = fullfile(base_dir, 'template_stop.png');
result_folder = fullfile(base_dir, 'results');

if ~isfolder(img_folder)
    error('Test image directory not found: %s. Create a "test images" folder beside the script.', img_folder);
end
if ~isfolder(result_folder)
    [created, message] = mkdir(result_folder);
    if ~created
        error('Cannot create results directory: %s. Reason: %s', result_folder, message);
    end
end

%% Detection parameters
param.hsv_h_low   = 0.95;
param.hsv_h_high  = 0.09;
param.hsv_s_low   = 0.25;
param.hsv_v_low   = 0.11;
param.min_area    = 500;
param.max_area    = 150000;  % Diagnostic counter only; not a rejection threshold.
param.approx_eps  = 0.032;  % Reserved parameter; currently unused.
param.ncc_thresh  = 0.3;
% Allow text-region and red-coverage evidence for border variants.
param.border_variant_ncc_thresh = 0.25;
param.border_variant_text_thresh = 0.25;
param.border_variant_red_thresh = 0.60;
param.use_histeq  = false;

%% Load the template and its eight vertices
if ~isfile(template_path)
    template_path = fullfile(base_dir, 'template_stop.jpg');
    if ~isfile(template_path)
        error('Template not found. Place template_stop.png or template_stop.jpg in: %s', base_dir);
    end
end
template = imread(template_path);
fprintf('Loaded template: %s\n', template_path);

points_path = fullfile(base_dir, 'template_points.mat');
if ~isfile(points_path)
    error('Cannot find %s. Run manual_template_points.m to annotate eight vertices.', points_path);
end
data = load(points_path, 'pts');
if ~isfield(data, 'pts') || size(data.pts, 1) ~= 8 || size(data.pts, 2) ~= 2
    error('The pts variable in template_points.mat must be an 8-by-2 vertex matrix. Repeat the annotation.');
end
template_pts = data.pts;
fprintf('Loaded annotated template vertices\n');

%% Collect test images
img_files = [dir(fullfile(img_folder, '*.jpg'));
             dir(fullfile(img_folder, '*.jpeg'));
             dir(fullfile(img_folder, '*.png'));
             dir(fullfile(img_folder, '*.bmp'))];
if isempty(img_files)
    error('No test images found in "%s".', img_folder);
end
fprintf('Found %d test images\n\n', length(img_files));

%% Detect and visualize each image
results = struct();
for i = 1:length(img_files)
    fprintf('========== [%2d/%2d] %s ==========\n', i, length(img_files), img_files(i).name);
    param.debug_candidates = any(strcmp(img_files(i).name, ...
        {'1.jpg', '4.jpg', '5.jpg', '8.jpg'}));
    img = imread(fullfile(img_folder, img_files(i).name));
    [best_pts, best_score, rectified, debug_info] = ...
        detect_stop_sign(img, template, template_pts, param);

    results(i).name    = img_files(i).name;
    results(i).pts     = best_pts;
    if isempty(best_pts)
        results(i).score = NaN;  % No matching score is available without a selected candidate.
    else
        results(i).score = best_score;
    end
    text_match = ~isempty(best_pts) && ...
        best_score >= param.border_variant_ncc_thresh && ...
        debug_info.best_core_score >= param.border_variant_text_thresh && ...
        debug_info.best_red_fraction >= param.border_variant_red_thresh;
    results(i).success = ~isempty(best_pts) && ...
        (best_score >= param.ncc_thresh || text_match);
    results(i).text_match = text_match && best_score < param.ncc_thresh;

    figure('Name', img_files(i).name, 'NumberTitle', 'off', ...
           'Position', [50 50 1500 520]);

    subplot(1,3,1);
    imshow(img);
    if isempty(best_pts)
        title('Detection (NCC not computed)', 'FontSize', 12);
    else
        title(sprintf('Detection (NCC=%.3f)', best_score), 'FontSize', 12);
    end
    if results(i).success
        hold on;
        plot([best_pts(:,1); best_pts(1,1)], [best_pts(:,2); best_pts(1,2)], ...
             'g-', 'LineWidth', 2.5);
        plot(best_pts(:,1), best_pts(:,2), 'yo', 'MarkerSize', 7, 'MarkerFaceColor', 'y');
        if results(i).text_match
            label = sprintf('NCC: %.3f (auxiliary acceptance)', best_score);
        else
            label = sprintf('NCC: %.3f', best_score);
        end
        text(15, 35, label, ...
             'Color', 'green', 'FontSize', 13, 'FontWeight', 'bold', ...
             'BackgroundColor', [0 0 0 0.5]);
    else
        text(15, 35, 'No STOP sign detected', 'Color', 'red', 'FontSize', 13, ...
             'FontWeight', 'bold', 'BackgroundColor', [0 0 0 0.5]);
    end

    subplot(1,3,2);
    if ~isempty(debug_info.mask)
        imshow(debug_info.mask);
        if param.debug_candidates
            hold on;
            for j = 1:numel(debug_info.candidates)
                pts = debug_info.candidates{j};
                center = mean(pts, 1);
                if j == debug_info.best_candidate
                    line_color = 'g';
                else
                    line_color = 'y';
                end
                plot([pts(:,1); pts(1,1)], [pts(:,2); pts(1,2)], ...
                     '-', 'Color', line_color, 'LineWidth', 1);
                text(center(1), center(2), num2str(j), 'Color', 'cyan', ...
                     'FontSize', 9, 'FontWeight', 'bold');
            end
            title('Red mask and candidates (green: highest NCC)', 'FontSize', 12);
        else
            title('Red-region segmentation', 'FontSize', 12);
        end
    else
        imshow(zeros(size(img,1), size(img,2)));
        title('No red regions', 'FontSize', 12);
    end

    subplot(1,3,3);
    if ~isempty(rectified)
        imshow(rectified);
        title('Rectified patch (for NCC)', 'FontSize', 12);
    else
        imshow(zeros(200,200));
        title('Rectification failed', 'FontSize', 12);
    end

    [~, image_name] = fileparts(img_files(i).name);
    saveas(gcf, fullfile(result_folder, ['result_' image_name '.png']));
    if results(i).success
        flag = 'Accepted';
    else
        flag = 'Rejected';
    end
    if isempty(best_pts)
        fprintf('  -> NCC not computed   [%s]\n\n', flag);
    else
        if results(i).text_match
            fprintf('  -> Best NCC = %.4f, text NCC = %.4f, red fraction %.2f; auxiliary acceptance   [%s]\n\n', best_score, ...
                    debug_info.best_core_score, debug_info.best_red_fraction, flag);
        else
            fprintf('  -> Best NCC = %.4f   [%s]\n\n', best_score, flag);
        end
    end
end

%% Summarize detection results
fprintf('\n\n====================== Detection summary =====================\n');
success_count = 0;
for i = 1:length(results)
    if results(i).success
        success_count = success_count + 1;
        flag = 'Accepted';
    else
        flag = 'Rejected';
    end
    if isnan(results(i).score)
        fprintf('%2d. %-35s  NCC = not computed   [%s]\n', i, results(i).name, flag);
    else
        fprintf('%2d. %-35s  NCC = %6.3f   [%s]\n', ...
                i, results(i).name, results(i).score, flag);
    end
    if results(i).text_match
        fprintf('     (Accepted by text/red criteria; combined score remains below %.2f)\n', param.ncc_thresh);
    end
end
fprintf('----------------------------------------------------------\n');
fprintf('Accepted detections: %d / %d\n', success_count, length(results));
fprintf('Result images saved to: %s\n', result_folder);
fprintf('==========================================================\n');
