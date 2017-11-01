function samples = event_to_sample(D,event_type,modality)
    % Map a specific event type to sample-sized logical array in continuous case
    % Returns logical array with 'true' wherever a matching event contains the sample
    % event_type will detect only events with the specified type string
    % modality will then filter based on modality
    % Both inputs can be cell arrays to match and filter against multiple strings
    
    if nargin < 3 || isempty(modality) 
        modality = {};
    end

    if nargin < 2 || isempty(event_type) 
        event_type = {};
    end
    

    assert(strcmp(D.type,'continuous'),'This function is only meant to operate on continuous MEEGs')
    
    samples = false(size(D.time));

    if ischar(event_type) || isstr(event_type)
    	event_type = {event_type};
    end

    ev = D.events(1,'samples');
    
    % If no events, return immediately
    if isempty(ev)
        return
    end
    
    keep_events = true(1,length(ev));

    if ~isempty(event_type)
        keep_events = keep_events & ismember({ev.type},event_type);
    end

    if ~isempty(modality)
        keep_events = keep_events & ismember({ev.value},modality);
    end

    ev = ev(keep_events);
    for j = 1:length(ev)
    	samples(ev(j).sample+(0:(ev(j).duration-1))) = true;
    end



