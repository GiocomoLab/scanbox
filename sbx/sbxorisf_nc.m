function C = sbxorisf(fname,tau)
% Orientation/Sf Kernel stats from randorisf experiment signals


% -----
if contains(fname,'rigid') % search for rigid in filename
    si = strfind(fname,'_');
    fnamelog = fname( 1:si(end)-1); % remove it
else
    fnamelog = fname;
end
% -----

%%
log = sbxreadorisflog(fnamelog); % read log
log = log{1};       % assumes only 1 trial
max_ori = max(abs(log.ori))+1;
max_sphase = max(abs(log.sphase))+1;
max_sper = max(abs(log.sper))+1;

load([fname, '.signals'],'-mat');    % load signals

dsig = spks;

ncell = size(dsig,2);
nstim = size(log,1);


r = cell(max_ori,max_sphase,max_sper,ncell);

disp('Processing...');
for(i=1:nstim)
    for w = 1:ncell
        a = r{log.ori(i)+1,log.sphase(i)+1,log.sper(i)+1,w};
        r{log.ori(i)+1,log.sphase(i)+1,log.sper(i)+1,w} = [a dsig(log.sbxframe(i)+tau,w)];
    end
end

C = zeros(ncell,ncell);
N = zeros(ncell,ncell);


for i = 1:ncell-1
    for j = (i+1):ncell
        for o = 1:max_ori
            for s = 1:max_sper
                li = [];
                lj = [];
                
                for p = 1:max_sphase
                    li = [li(:) ; r{o,p,s,i}(:)];
                    lj = [lj(:) ; r{o,p,s,j}(:)];
                end
                
                if(length(li) >= 10 && (sum(li)>0 && sum(lj)>0))    % minimum number of repeats
                    [rho,~] = corrcoef(li,lj);
                    C(i,j) = C(i,j) + rho(1,2);
                    N(i,j) = N(i,j)+1;
                end
            end
        end
    end
end

C = C./N;

save([fname '.orisf_nc'],'C', 'r', 'tau');

