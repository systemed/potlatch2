package net.systemeD.potlatch2.controller {

    import flash.events.Event;

	/**
	 *	ControllerEvents are used to help aspects of the Flex user interface
	 *	(for example, the tutorial window or toolbox) to listen in to the
	 *  user's actions, and respond to it. */

    public class ControllerEvent extends Event {

		public static const ENTER_STATE:String = "enter";
		public static const EXIT_STATE:String = "exit";
		public static const SELECTION:String = "select";

		public var state:ControllerState;

        public function ControllerEvent(eventname:String, state:ControllerState) {
            super(eventname);
            this.state=state;
        }
    }

}
