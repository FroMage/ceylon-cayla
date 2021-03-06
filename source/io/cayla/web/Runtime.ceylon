import io.vertx.ceylon { Vertx }
import io.vertx.ceylon.http { HttpServerRequest }
import ceylon.promises { Promise }
import ceylon.collection { HashMap }
"""The application runtime.
   
   The runtime is obtained from the [[Application.start]] method.
   """
shared class Runtime("The application" shared Application application, "Vert.x" shared Vertx vertx) {
	
	"Handles the Vert.x request and dispatch it to a controller"
	shared void handle(HttpServerRequest request) {
		
		// When there is a body, we are invoked by Vert.x before parsing this body
		// so we need to use the Promise<Map<String, {String+}> to get the form
		
		// When there is a form we get it
		Map<String, {String+}> withForm(Map<String, {String+}> form) {
			return form;
		}
		// Otherwise we fail but we just return an empty map
		Map<String, {String+}> withoutForm(Exception ignore) {
			return emptyMap;
		}
		
		// Dispatch now the request + form in Cayla
		void dispatch(Map<String, {String+}> form) {
			value result = _handle(request, form);
			switch (result)
			case (is Response) {
				result.send(request.response);
			}
			case (is Promise<Response>) {
				void f(Response response) {
					response.send(request.response);
				}
				void g(Exception reason) {
					error {
						reason.message;
					}.send(request.response);
				}
				result.then_(f, g);
			}
		}
		
		// Chain stuff
		request.formAttributes.then_(withForm, withoutForm).then_(dispatch);
	}

	"Handles the Vert.x request and dispatch it to a controller"
	Promise<Response>|Response _handle(HttpServerRequest request, Map<String, {String+}> form) {

		for (match in application.descriptor.resolve(request.uri.path.string)) {
			
			value desc = match.target;
			
			// Todo : make request return ceylon.net.http::Method instead
			value method = request.method;
			if (desc.methods.size == 0 || desc.methods.contains(method)) {

				// Merge parameters : query / form / path
				HashMap<String, String> parameters = HashMap<String, String> { 
					for (params in [request.params, form])
    					for (param in params)
    					   param.key->param.item.first
				};
				for (param in match.params) {
					parameters.put(param.key, param.item);
				}
				
				// Attempt to create controller
				Handler controller;
				try {
					controller = match.target.instantiate(*parameters);
				} catch (Exception e) {
					// Somehow should distinguish the kind of error
					// and return an appropriate status code
					// missing parameter    -> 400
					// invocation exception -> 500
					// etc...
					return error {
						"Could not create controller for ``request.path`` with ``parameters``: ``e.message``";
					};
				}
				
				//
				value context = RequestContext(this, request);
				current.set(context);
				try {
					return controller.invoke(context);
				}
				catch (Exception e) {
					return error {
						e.message;
				    };
				}
				finally {
					current.set(null);
				}
			}
		}		
		return notFound {
			"Could not match a controller for ``request.path``";
		};
	}
	
	"Stop the application"
	shared void stop() {
		vertx.stop();
	}
}

