function [hmm,Gamma,Xi,fehist,actstates]=hmmtrain(data,T,hmm,Gamma,residuals)
%
% Train Hidden Markov Model using using Variational Framework
%
% INPUTS:
%
% data          observations - a struct with X (time series) and C (classes)
% T             Number of time points for each time series
% hmm           hmm structure with options specified in hmm.train
% Gamma         Initial state courses
% residuals     in case we train on residuals, the value of those.
%
% OUTPUTS
% hmm           estimated HMMMAR model
% Gamma         estimated p(state | data)
% Xi            joint probability of past and future states conditioned on data
% fehist        historic of the free energies across iterations
% knocked       states knocked out by the Bayesian inference
%
% hmm.Pi          - intial state probability
% hmm.P           - state transition matrix
% hmm.state(k).$$ - whatever parameters there are in the observation model
%
% Author: Diego Vidaurre, OHBA, University of Oxford

N = length(T); K = hmm.train.K;
ndim = size(data.X,2);

[~,order] = formorders(hmm.train.order,hmm.train.orderoffset,hmm.train.timelag,hmm.train.exptimelag);

fehist=[];
actstates = ones(1,K);

checkpts = hmm.train.cyc(1:end-1);
max_cyc = hmm.train.cyc(end);
cyc_to_go = 0;

for cycle=1:max_cyc
    
    if hmm.train.updateGamma,
              
        %%%% E step
        if hmm.K>1 || cycle==1    
            [Gamma,Gammasum,Xi]=hsinference(data,T,hmm,residuals);
            %if cycle==1 
            %    load('shit.mat'); 
            %end
            if size(Gammasum,1)>1, Gammasum = sum(Gammasum); end
            if (hmm.K>1 && any(round(Gammasum) == sum(T)-N*order))
                fprintf('cycle %i: All the points collapsed in one state \n',cycle)
                break
            end
        end
        % any state to remove? 
        as1 = find(actstates==1);
        [as,hmm,Gamma,Xi] = getactivestates(data.X,hmm,Gamma,Xi);
        if any(as==0), cyc_to_go = hmm.train.cycstogoafterevent; end
        actstates(as1(as==0)) = 0;
        
        %%%% Free energy computation
        fehist = [fehist; sum(evalfreeenergy(data.X,T,Gamma,Xi,hmm,residuals))];
        strwin = ''; if hmm.train.meancycstop>1, strwin = 'windowed'; end
        if cycle>(hmm.train.meancycstop+1) && cyc_to_go==0
            chgFrEn = mean( fehist(end:-1:(end-hmm.train.meancycstop+1)) - fehist(end-1:-1:(end-hmm.train.meancycstop)) )  ...
                / (fehist(1) - fehist(end));
               %/ abs(mean(fehist(end-1:-1:(end-hmm.train.meancycstop)))) * 100;
            %if chgFrEn>0.03, keyboard; end
            if hmm.train.verbose, fprintf('cycle %i free energy = %g, %s relative change = %g \n',cycle,fehist(end),strwin,chgFrEn); end
            if (-chgFrEn < hmm.train.tol), break; end
        elseif hmm.train.verbose && cycle>1, fprintf('cycle %i free energy = %g \n',cycle,fehist(end));
        end
        if cyc_to_go>0, cyc_to_go = cyc_to_go - 1; end
        
        % save to a intermediate file
        if ~isempty(checkpts) && (cycle == checkpts(1)) && ~isempty(hmm.train.checkpt_fname)
            checkpt_fname = strcat(hmm.train.checkpt_fname,'-cyc',num2str(cycle));
            save(checkpt_fname,'hmm','Gamma','Xi','fehist','actstates','residuals','-v7.3');
            if hmm.train.verbose, fprintf('Saving to %s\n', checkpt_fname);  end
            checkpts=checkpts(2:end);
        end
        
    else
        Xi=[]; fehist=0;
    end
    
    %%%% M STEP
       
    % Observation model
    hmm=obsupdate(data.X,T,Gamma,hmm,residuals);
    
    if hmm.train.updateGamma,
        % transition matrices and initial state
        hmm=hsupdate(Xi,Gamma,T,hmm);
    else
        break % one is more than enough
    end
    
end

if hmm.train.verbose
    fprintf('Model: %d kernels, %d dimension(s), %d data samples \n',K,ndim,sum(T));
end

return;

