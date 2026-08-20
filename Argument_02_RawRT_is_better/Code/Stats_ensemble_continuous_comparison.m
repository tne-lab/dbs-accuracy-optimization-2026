% Script_ensemble_continuous_comparison
% ============================================================
% PARADIGM COMPARISON: Continuous vs. Ensemble per Algorithm
% Goal: Evaluate if Continuous > Ensemble for each algorithm.
% Tests Applied:
%   1. Paired Student's t-test (Parametric)
%   2. Wilcoxon Signed-Rank Test (Non-parametric)
%   3. Cohen's d (Effect Size)
%  ============================================================

fprintf('\n=========================================================================================\n');
fprintf('         PARADIGM EFFECT ANALYSIS: CONTINUOUS vs. ENSEMBLE (N = 7 Checkpoints)            \n');
fprintf('=========================================================================================\n\n');

% Function for paired Cohen's d calculation
calc_cohen_d = @(x, y) mean(x - y) / std(x - y);

% --- 1. Dynamic Data Extraction ---
fieldsEns = fieldnames(resEns);
fieldsCon = fieldnames(resCon);
algList   = intersect(fieldsEns, fieldsCon);

% Reorder to place 'noalgorithm' at the bottom
if ismember('noalgorithm', algList)
    algList = [setdiff(algList, 'noalgorithm'); {'noalgorithm'}];
end

numAlgs = length(algList);
dataMatrix_Con = nan(numAlgs, numDays);
dataMatrix_Ens = nan(numAlgs, numDays);
algLabels      = cell(numAlgs, 1);

pldEns = 'Day'; if ~isfield(resEns.(algList{1}), pldEns), pldEns = 'Iterations'; end

for a = 1:numAlgs
    algName = algList{a};
    
    if strcmpi(algName, 'noalgorithm')
        algLabels{a} = 'Brute Force';
    else
        algLabels{a} = upper(algName);
    end
    
    for d = 1:numDays
        dayField  = sprintf('Day%d', dayList(d));
        iterField = sprintf('Iter%d', iterationList(d));
        
        if isfield(resEns.(algName), pldEns) && isfield(resEns.(algName).(pldEns), dayField)
            dataMatrix_Ens(a, d) = resEns.(algName).(pldEns).(dayField).Mean_Selection_accuracy(1);
        end
        if isfield(resCon.(algName), 'Iterations') && isfield(resCon.(algName).Iterations, iterField)
            dataMatrix_Con(a, d) = resCon.(algName).Iterations.(iterField).Mean_Selection_accuracy(1);
        end
    end
end

% --- 2. Compute Paradigm Effects ---
stratCol   = strings(numAlgs, 1);
conMeanCol = zeros(numAlgs, 1);
ensMeanCol = zeros(numAlgs, 1);
gainCol    = zeros(numAlgs, 1);

% Parametric Test (Paired t-test)
tStatCol   = zeros(numAlgs, 1);
tPValCol   = zeros(numAlgs, 1);

% Non-Parametric Test (Wilcoxon Signed-Rank)
wPValCol   = zeros(numAlgs, 1);

% Effect Size
cohenDCol  = zeros(numAlgs, 1);

for a = 1:numAlgs
    x_con = dataMatrix_Con(a, :);
    x_ens = dataMatrix_Ens(a, :);
    
    % Statistical Tests
    [~, p_t, ~, stats_t] = ttest(x_con, x_ens);
    p_w                  = signrank(x_con, x_ens);
    d_val                = calc_cohen_d(x_con, x_ens);
    gain_val             = (mean(x_con) - mean(x_ens)) * 100;
    
    % Store
    stratCol(a)   = string(algLabels{a});
    conMeanCol(a) = mean(x_con) * 100;
    ensMeanCol(a) = mean(x_ens) * 100;
    gainCol(a)    = gain_val;
    tStatCol(a)   = stats_t.tstat;
    tPValCol(a)   = p_t;
    wPValCol(a)   = p_w;
    cohenDCol(a)  = d_val;
end

% Build Table
t_paradigm = table(stratCol, conMeanCol, ensMeanCol, gainCol, ...
    tStatCol, tPValCol, wPValCol, cohenDCol, ...
    'VariableNames', { ...
        'Algorithm', 'Continuous_Mean', 'Ensemble_Mean', 'Gain_Pct', ...
        't_statistic', 't_Test_pVal', 'Wilcoxon_pVal', 'Cohens_d' ...
    });

% --- 3. Display Results ---
fprintf('Algorithm       | Con Mean | Ens Mean | Gain %%   | t-stat   | t-test p-val | Wilcoxon p-val | Cohen''s d\n');
fprintf('-------------------------------------------------------------------------------------------------------\n');
for r = 1:height(t_paradigm)
    fprintf('%-15s | %5.2f%%   | %5.2f%%   | %+6.2f%% | %8.2f | %12.4e | %14.4e | %8.2f\n', ...
        t_paradigm.Algorithm(r), ...
        t_paradigm.Continuous_Mean(r), ...
        t_paradigm.Ensemble_Mean(r), ...
        t_paradigm.Gain_Pct(r), ...
        t_paradigm.t_statistic(r), ...
        t_paradigm.t_Test_pVal(r), ...
        t_paradigm.Wilcoxon_pVal(r), ...
        t_paradigm.Cohens_d(r));
end
fprintf('=======================================================================================================\n\n');

% --- 4. Export Struct ---
ParadigmStats = struct();
ParadigmStats.ParadigmEffectTable = t_paradigm;
ParadigmStats.RawData.Continuous   = dataMatrix_Con;
ParadigmStats.RawData.Ensemble     = dataMatrix_Ens;
ParadigmStats.RawData.Algorithms   = algLabels;

fprintf('>> Exported to struct: ParadigmStats.ParadigmEffectTable\n\n');