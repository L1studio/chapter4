function [x, info] = tdma_allo(sig, fs, varargin)
%TDMA_ALLO 模拟时分多址/突发信号生成
% 输入:
%   sig: 原始连续信号 (向量)
%   fs:  采样率 (Hz)
%   varargin: 可选参数 (OnMs, OffMs, Seed)
% 输出:
%   x:    经过切分处理后的信号 (OFF部分被置零)
%   info: 结构体，包含 ON 和 OFF 的起止索引 (用于制作标签)

    % ---- 1. 参数解析与配置 ----
    p = inputParser; % 创建参数解析器对象
    % 设置默认的发送时长范围 [0.4ms, 3.2ms] (0.04*10 ~ 0.04*80)
    addParameter(p,'OnMs',[0.04*10 0.04*80],@(v)isnumeric(v)&&numel(v)==2&&v(1)>0&&v(2)>=v(1));
    % 设置默认的静默时长范围 [0.4ms, 3.2ms]
    addParameter(p,'OffMs',[0.04*10 0.04*80],@(v)isnumeric(v)&&numel(v)==2&&v(1)>0&&v(2)>=v(1));
    % 设置随机种子
    addParameter(p,'Seed',NaN,@(x)isnumeric(x)&&isscalar(x));
    
    parse(p,varargin{:}); % 解析输入参数
    on_ms  = p.Results.OnMs;
    off_ms = p.Results.OffMs;
    Seed   = p.Results.Seed;
    
    if ~isnan(Seed), rng(Seed); end % 如果指定了种子，则固定随机状态
    
    % ---- 2. 预处理与单位转换 ----
    was_col = iscolumn(sig); % 记录输入信号是否为列向量，以便最后还原形状
    x = sig(:).';            % 强制展平为行向量，方便统一处理
    N = numel(x);            % 获取信号总采样点数
    
    % 将时间单位(ms)转换为采样点数(Sample Points)
    % 公式: 点数 = 毫秒数 * 1e-3 * 采样率
    on_minS  = max(1, round(on_ms(1)  * 1e-3 * fs)); % ON 状态最小点数
    on_maxS  = max(on_minS,  round(on_ms(2)  * 1e-3 * fs)); % ON 状态最大点数
    off_minS = max(1, round(off_ms(1) * 1e-3 * fs)); % OFF 状态最小点数
    off_maxS = max(off_minS, round(off_ms(2) * 1e-3 * fs)); % OFF 状态最大点数
    
    % ---- 3. 核心切分逻辑 ----
    % 随机决定第一段是“发送(ON)”还是“静默(OFF)”，各50%概率
    is_on = rand < 0.5;      % true=ON, false=OFF
    pos   = 1;               % 当前处理到的起始采样点索引
    mask  = false(1,N);      % 初始化掩码，全为0 (默认全OFF)。后续将ON的位置置为true
    segs  = [];              % 用于临时存储分段起止点 [start, end]
    types = [];              % 用于记录每一段的类型 (1=ON, 0=OFF)
    
    while pos <= N % 只要还没处理到信号末尾，就继续循环
        % 根据当前状态 (ON/OFF)，确定这一段长度的随机范围 [Lmin, Lmax]
        % 并确定“下一段”允许的最小长度 next_min (用于边界检查)
        if is_on
            Lmin = on_minS; Lmax = on_maxS; next_min = off_minS;
        else
            Lmin = off_minS; Lmax = off_maxS; next_min = on_minS;
        end
        
        remS = N - pos + 1; % 计算信号尾部还剩多少个点可用
        
        % [边界处理逻辑 A]：如果剩余长度连当前状态的最小要求都不满足
        if remS < Lmin
            % 策略：不单独成段，而是直接并入“上一段”。
            if ~isempty(segs)
                segs(end,2) = N; % 延长上一段的结束点到信号末尾
                % 如果上一段是 ON，则需要把新增的这部分 mask 也设为 true
                if types(end)==1, mask(segs(end,1):segs(end,2)) = true; end
            else
                % 极端情况：整个信号太短，连第一段的最小长度都不够
                segs = [1 N]; types = double(is_on); % 只能强行做成一段
                if is_on, mask(1:N) = true; end
            end
            break; % 处理完毕，跳出循环
        end
        
        % [正常长度分配]：在允许范围内随机生成当前段长度 L
        L = randi([Lmin, Lmax]);
        L = min(L, remS); % 防止生成的长度越界（虽然通常 remS > Lmin）
        
        % [边界处理逻辑 B - 前瞻检查]
        % 如果把当前段放进去后，剩下的空间 (remS - L) 不足以容纳“下一段的最小长度”
        % 那么为了避免最后剩下一个极短的畸形段，直接把所有剩余空间都归给当前段吃掉。
        if (remS - L) > 0 && (remS - L) < next_min
            L = remS;    % 吞并剩余所有点数
        end
        
        % [记录当前段]
        s = pos; e = pos + L - 1; % 计算当前段的起止索引
        segs  = [segs;  s e];           %#ok<AGROW> % 存入分段列表
        types = [types; double(is_on)]; %#ok<AGROW> % 存入类型列表
        
        % 如果当前状态是 ON，则在掩码中将对应位置设为 true (保留信号)
        if is_on, mask(s:e) = true; end
        
        % [状态更新]
        pos   = e + 1;  % 指针移动到下一段的开头
        is_on = ~is_on; % 状态翻转：ON 变 OFF，或 OFF 变 ON (交替进行)
    end
    
    % ---- 4. 应用掩码 (物理切分) ----
    % 将 mask 为 false 的位置（即 OFF 阶段）的数据强制置零
    % 这就是把连续波变成断续波的关键步骤
    x(~mask) = 0;
    
    % ---- 5. 输出格式整理 ----
    if was_col, x = x.'; end % 如果输入是列向量，输出也还原为列向量
    
    % 提取 ON 和 OFF 段的起止索引，存入 info 结构体
    % 这些数据将用于生成深度学习的目标检测框 (Bounding Box)
    on_iv   = segs(types==1,:);
    off_iv  = segs(types==0,:);
    info = struct();
    info.on_iv      = on_iv;
    info.off_iv     = off_iv;
end