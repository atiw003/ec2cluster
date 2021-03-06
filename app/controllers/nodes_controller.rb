class NodesController < ApplicationController
  layout 'green'
  
  
  before_filter :find_job
  
  # GET /nodes
  # GET /nodes.xml
  def index
    @nodes = @job.nodes.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @nodes }
      format.json  { render :json => @nodes }
    end
  end

  # GET /nodes/1
  # GET /nodes/1.xml
  def show
    @node = Node.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @node }
      format.json  { render :json => @node }      
    end
  end

  # GET /nodes/new
  # GET /nodes/new.xml
  def new
    @node = @job.nodes.build 
    
    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @node }
      format.json  { render :json => @node }      
    end
  end

  # GET /nodes/1/edit
  def edit
    @node = @job.nodes.find(params[:id])
  end

  # POST /nodes
  # POST /nodes.xml
  def create
    @node = Node.new(params[:node])

    respond_to do |format|
      if (@job.nodes << @node)
        flash[:notice] = 'Node was successfully created.'
        format.html { redirect_to job_url(@job) }
        format.xml  { render :xml => @node, :status => :created, :location => @node }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @node.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /nodes/1
  # PUT /nodes/1.xml
  def update
    @node = @job.nodes.find(params[:id])
    
    respond_to do |format|
      # When all nodes report ready, a nextstep action is triggered on the job.
      if @node.update_attributes(params[:node])
        
        if @job.state == "waiting_for_nodes"
          # check if all nodes have finished installs/configuration
          @ready_nodes = @job.nodes.find(:all, :conditions => {:is_configured => true })
          if @ready_nodes.size == @job.number_of_instances
            @job.nextstep!  # waiting_for_nodes - > exporting_master_nfs
            puts "All nodes have reported ready, configuring cluster host file and starting NFS export"
          end 
        elsif @job.state == "exporting_master_nfs"
          # trigger transition when nfs_mounted => true for master node...
          # find master node by checking if instance_id = master_instance_id, 
          master_instance_id = @job.master_instance_id
          @master_node = @job.nodes.find(:first, :conditions => {:aws_instance_id => master_instance_id })
          # check if nfs_mounted is true for master node, if so - transition.            
          if @master_node.nfs_mounted
            @job.nextstep!  # exporting_master_nfs -> mounting_nfs
            puts "Master node has exported NFS home, ready for worker nodes to begin mounting volume"            
          end                  
        elsif @job.state == "mounting_nfs"  
          # check if all nodes have mounted NFS home directory
          @mounted_nodes = @job.nodes.find(:all, :conditions => {:nfs_mounted => true })
          if @mounted_nodes.size == @job.number_of_instances
            @job.nextstep!  # mounting_nfs - > configuring_cluster
            puts "All nodes mounted NFS volumes, cluster ready for MPI jobs"
          end          
        end  
        
        flash[:notice] = 'Node was successfully updated.'
        format.html { redirect_to job_url(@job) }
        format.xml  { head :ok }
        format.json  { head :ok }        
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @node.errors, :status => :unprocessable_entity }
        format.json  { render :json => @job.errors, :status => :unprocessable_entity }         
      end
    end
  end

  # DELETE /nodes/1
  # DELETE /nodes/1.xml
  def destroy
    node = @job.nodes.find(params[:id])
    @job.nodes.delete(node)

    respond_to do |format|
      format.html { redirect_to job_url(@job) }
      format.xml  { head :ok }
    end
  end
  
  
  
private

  def find_job
    @job_id = params[:job_id]
    return(redirect_to(jobs_url)) unless @job_id
    @job = Job.find(@job_id)
  end
  
end
