% MAIN_STOP_DETECTION Detect STOP signs and save result figures.
clear; clc; close all;

%% Paths
% Keep functions, the template, and template_points.mat in this folder.
% Read test images from "test images" and save figures to "results".
base_dir = fileparts(mfilename('fullpath'));
if isempty(base_dir)
    error('无法定位主程序目录。请保存 main_stop_detection.m 后再运行。');
end
addpath(base_dir);
img_folder    = fullfile(base_dir, 'test images');
template_path = fullfile(base_dir, 'template_stop.png');
result_folder = fullfile(base_dir, 'results');

if ~isfolder(img_folder)
    error('找不到测试图片目录：%s。请在主程序同级目录创建 "test images" 文件夹。', img_folder);
end
if ~isfolder(result_folder)
    [created, message] = mkdir(result_folder);
    if ~created
        error('无法创建结果文件夹：%s。原因：%s', result_folder, message);
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
        error('找不到模板图片，请将 template_stop.png 或 template_stop.jpg 放入：%s', base_dir);
    end
end
template = imread(template_path);
fprintf('成功读取模板: %s\n', template_path);

points_path = fullfile(base_dir, 'template_points.mat');
if ~isfile(points_path)
    error('找不到 %s。请先运行 manual_template_points.m 标注八个顶点。', points_path);
end
data = load(points_path, 'pts');
if ~isfield(data, 'pts') || size(data.pts, 1) ~= 8 || size(data.pts, 2) ~= 2
    error('template_points.mat 中的 pts 必须是 8×2 顶点矩阵，请重新标注。');
end
template_pts = data.pts;
fprintf('成功加载手动标注的模板顶点\n');

%% Collect test images
img_files = [dir(fullfile(img_folder, '*.jpg'));
             dir(fullfile(img_folder, '*.jpeg'));
             dir(fullfile(img_folder, '*.png'));
             dir(fullfile(img_folder, '*.bmp'))];
if isempty(img_files)
    error('在 "%s" 中没有找到测试图像。', img_folder);
end
fprintf('共找到 %d 张测试图像\n\n', length(img_files));

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
        title('原图检测结果 (NCC 未计算)', 'FontSize', 12);
    else
        title(sprintf('原图检测结果 (NCC=%.3f)', best_score), 'FontSize', 12);
    end
    if results(i).success
        hold on;
        plot([best_pts(:,1); best_pts(1,1)], [best_pts(:,2); best_pts(1,2)], ...
             'g-', 'LineWidth', 2.5);
        plot(best_pts(:,1), best_pts(:,2), 'yo', 'MarkerSize', 7, 'MarkerFaceColor', 'y');
        if results(i).text_match
            label = sprintf('NCC: %.3f (文字区辅助通过)', best_score);
        else
            label = sprintf('NCC: %.3f', best_score);
        end
        text(15, 35, label, ...
             'Color', 'green', 'FontSize', 13, 'FontWeight', 'bold', ...
             'BackgroundColor', [0 0 0 0.5]);
    else
        text(15, 35, '未检测到STOP标志', 'Color', 'red', 'FontSize', 13, ...
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
            title('红色分割及候选编号（绿色为最高NCC）', 'FontSize', 12);
        else
            title('红色区域分割结果', 'FontSize', 12);
        end
    else
        imshow(zeros(size(img,1), size(img,2)));
        title('无红色区域', 'FontSize', 12);
    end

    subplot(1,3,3);
    if ~isempty(rectified)
        imshow(rectified);
        title('几何校正后 (用于NCC)', 'FontSize', 12);
    else
        imshow(zeros(200,200));
        title('校正失败', 'FontSize', 12);
    end

    [~, image_name] = fileparts(img_files(i).name);
    saveas(gcf, fullfile(result_folder, ['result_' image_name '.png']));
    if results(i).success
        flag = '成功';
    else
        flag = '失败';
    end
    if isempty(best_pts)
        fprintf('  → NCC 未计算   【%s】\n\n', flag);
    else
        if results(i).text_match
            fprintf('  → 最高NCC = %.4f，文字区 NCC = %.4f，红色占比 %.2f；通过文字区辅助判据   【%s】\n\n', best_score, ...
                    debug_info.best_core_score, debug_info.best_red_fraction, flag);
        else
            fprintf('  → 最高NCC = %.4f   【%s】\n\n', best_score, flag);
        end
    end
end

%% Summarize detection results
fprintf('\n\n====================== 最终检测汇总 =====================\n');
success_count = 0;
for i = 1:length(results)
    if results(i).success
        success_count = success_count + 1;
        flag = '成功';
    else
        flag = '失败';
    end
    if isnan(results(i).score)
        fprintf('%2d. %-35s  NCC = 未计算   [%s]\n', i, results(i).name, flag);
    else
        fprintf('%2d. %-35s  NCC = %6.3f   [%s]\n', ...
                i, results(i).name, results(i).score, flag);
    end
    if results(i).text_match
        fprintf('     （通过文字区与红色判据；全域 NCC 仍低于 %.2f）\n', param.ncc_thresh);
    end
end
fprintf('----------------------------------------------------------\n');
fprintf('成功检测数量: %d / %d\n', success_count, length(results));
fprintf('结果图像已保存至: %s\n', result_folder);
fprintf('==========================================================\n');
