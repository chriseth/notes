contract DeliveryDroneControl {
    /// @dev account of the drone itself
    address drone;

    struct Delivery { string from; string to; }
    Delivery[] public requestQueue;

    enum Status { Idle, Delivering, ToNextDelivery }
    Status public status;

// Event

    /// @dev constructor, stores the address of the drone.
    function DeliveryDroneControl(address _drone) {
        drone = _drone;
    }
    
    /// @notice request drone delivery from `from` to `to`.
    function requestDelivery(string from, string to) {
        /// construct the struct "Delivery" and assign it to storage.
        var queue = requestQueue; // stores reference to storage
        queue[queue.length++] = Delivery(from, to);
    }

    modifier calledByDrone() { if (msg.sender == drone) _ }

    /// @dev called by the drone to get the next location to fly to
    function getNextLocation() calledByDrone returns (string) {
        if (requestQueue.length == 0) return "";
        // @todo this is not actually a queue
        if (status == Status.Delivering)
            return requestQueue[0].to;
        else
            return requestQueue[0].from;
    }

    function delivered() calledByDrone {
    }
    
}

contract queue
{
    struct Queue {
	    uint[] data;
        uint front;
        uint back;
    }
    /// @dev the number of elements stored in the queue.
    function length(Queue storage q) constant internal returns (uint) {
        return q.back - q.front;
    }
    /// @dev the number of elements this queue can hold
    function capacity(Queue storage q) constant internal returns (uint) {
        return q.data.length - 1;
    }
    /// @dev push a new element to the back of the queue
    function push(Queue storage q, uint data) internal
    {
        if ((q.back + 1) % q.data.length == q.front)
            return; // throw;
        q.data[q.back] = data;
        q.back = (q.back + 1) % q.data.length;
    }
    /// @dev remove and return the element at the front of the queue
    function pop(Queue storage q) internal returns (uint r)
    {
        if (q.back == q.front)
            return; // throw;
        r = q.data[q.front];
        delete q.data[q.front];
        q.front = (q.front + 1) % q.data.length;
    }
}

contract QueueUserMayBeDeliveryDroneCotnrol is queue {
    Queue requests;
    function QueueUserMayBeDeliveryDroneCotnrol() {
        requests.data.length = 200;
    }
    function addRequest(uint d) {
        push(requests, d);
    }
    function popRequest() returns (uint) {
        return pop(requests);
    }
    function queueLength() returns (uint) {
        return length(requests);
    }
}

