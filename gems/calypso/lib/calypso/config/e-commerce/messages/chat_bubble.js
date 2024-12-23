$(document).ready(function() {
    $('#sendButton').click(function() {
        const message = $('#messageInput').val().trim();
        if (message === '') return;

        // Append user message to chat
        $('#messagesContainer').append(`
      <div class="flex justify-end mb-2">
        <div class="bg-blue-500 text-white p-2 rounded-lg max-w-xs">
          ${message}
        </div>
      </div>
    `);
        $('#messageInput').val('');

        // Send message to backend (API endpoint)
        $.ajax({
            url: '/api/chat/respond',
            method: 'POST',
            contentType: 'application/json',
            data: JSON.stringify({ message: message }),
            success: function(response) {
                // Append AI response to chat
                $('#messagesContainer').append(`
          <div class="flex justify-start mb-2">
            <div class="bg-gray-300 text-black p-2 rounded-lg max-w-xs">
              ${response.reply}
            </div>
          </div>
        `);
                // Scroll to the bottom
                $('#chatMessages').scrollTop($('#chatMessages')[0].scrollHeight);
            },
            error: function(error) {
                console.error('Error:', error);
            }
        });
    });

    // Handle Enter key for sending messages
    $('#messageInput').keypress(function(e) {
        if (e.which == 13 && !e.shiftKey) {
            e.preventDefault();
            $('#sendButton').click();
        }
    });
});




$(document).ready(function() {
    // Function to append a new received message
    function appendReceivedMessage(messageData) {
        const messageHTML = `
      <li class="max-w-lg flex gap-x-2 sm:gap-x-4 me-11">
        <img class="inline-block size-9 rounded-full" src="${messageData.avatar}" alt="Avatar">

        <!-- Received Message Bubble -->
        <div>
          <p class="mb-1.5 ps-2.5 text-xs text-gray-400 dark:text-neutral-500">${messageData.sender}</p>

          <div class="space-y-1">
            <!-- Message -->
            <div class="group flex justify-start gap-x-2" style="word-break: break-word;">
              <div class="order-1 bg-white shadow-sm dark:bg-neutral-800 dark:border-neutral-700 inline-block rounded-xl pt-2 pb-1.5 px-2.5">
                <div class="text-sm text-gray-800 dark:text-neutral-200">
                  <div class="flex items-center gap-x-2">
                    <button type="button" class="flex justify-center items-center size-9 bg-blue-600 hover:bg-blue-700 focus:outline-none focus:bg-blue-700 text-white rounded-full dark:bg-blue-500 dark:hover:bg-blue-600 dark:focus:bg-blue-600">
                      <svg class="shrink-0 size-4" xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polygon points="6 3 20 12 6 21 6 3"/></svg>
                    </button>
                    <div class="grow">
                      <p class="font-medium text-[13px] text-gray-800 dark:text-neutral-200">${messageData.filename}</p>
                      <p class="text-xs text-gray-500 dark:text-neutral-500">${messageData.filesize} - <a class="font-medium text-blue-600 hover:text-blue-700 focus:outline-none focus:text-blue-700 dark:text-blue-500 dark:focus:text-blue-600" href="${messageData.downloadLink}">Download</a></p>
                    </div>
                  </div>

                  <span>
                    <span class="text-[11px] text-gray-400 dark:text-neutral-600 italic">${messageData.timestamp}</span>
                  </span>
                </div>
              </div>

              <!-- More Dropdown -->
              <div class="order-2 lg:opacity-0 lg:group-hover:opacity-100">
                <div class="hs-dropdown [--strategy:absolute] [--auto-close:inside] relative inline-flex">
                  <button type="button" class="flex justify-center items-center gap-x-3 size-8 text-sm text-gray-600 hover:bg-gray-200 rounded-full disabled:opacity-50 disabled:pointer-events-none focus:outline-none focus:bg-gray-200 dark:text-neutral-400 dark:hover:bg-neutral-800 dark:focus:bg-neutral-800 dark:hover:text-neutral-200 dark:focus:text-neutral-200" aria-haspopup="menu" aria-expanded="false" aria-label="Dropdown">
                    <svg class="shrink-0 size-4 rounded-full" xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="1"/><circle cx="12" cy="5" r="1"/><circle cx="12" cy="19" r="1"/></svg>
                  </button>

                  <!-- More Dropdown Menu -->
                  <div class="hs-dropdown-menu hs-dropdown-open:opacity-100 w-32 transition-[opacity,margin] duration opacity-0 hidden z-[8] bg-white rounded-xl shadow-lg dark:bg-neutral-800 before:h-4 before:absolute before:-top-4 before:start-0 before:w-full after:h-4 after:absolute after:-bottom-4 after:start-0 after:w-full" role="menu" aria-orientation="vertical">
                    <div class="p-1">
                      <a class="flex items-center gap-x-3 py-1.5 px-2 rounded-lg text-xs text-gray-800 hover:bg-gray-100 disabled:opacity-50 disabled:pointer-events-none focus:outline-none focus:bg-gray-100 dark:text-neutral-300 dark:hover:bg-neutral-700 dark:focus:bg-neutral-700" href="#">
                        <svg class="shrink-0 size-3.5" xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 3a2.85 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5Z"/><path d="m15 5 4 4"/></svg>
                        Edit
                      </a>
                      <a class="flex items-center gap-x-3 py-1.5 px-2 rounded-lg text-xs text-gray-800 hover:bg-gray-100 disabled:opacity-50 disabled:pointer-events-none focus:outline-none focus:bg-gray-100 dark:text-neutral-300 dark:hover:bg-neutral-700 dark:focus:bg-neutral-700" href="#">
                        <svg class="shrink-0 size-3.5" xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/><path d="m10 7-3 3 3 3"/></svg>
                        Reply
                      </a>
                      <a class="flex items-center gap-x-3 py-1.5 px-2 rounded-lg text-xs text-gray-800 hover:bg-gray-100 disabled:opacity-50 disabled:pointer-events-none focus:outline-none focus:bg-gray-100 dark:text-neutral-300 dark:hover:bg-neutral-700 dark:focus:bg-neutral-700" href="#">
                        <svg class="shrink-0 size-3.5" xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 6h18"/><path d="M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6"/><path d="M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2"/><line x1="10" x2="10" y1="11" y2="17"/><line x1="14" x2="14" y1="11" y2="17"/></svg>
                        Delete
                      </a>
                    </div>
                  </div>
                  <!-- End More Dropdown Menu -->
                </div>
              </div>
              <!-- End More Dropdown -->
            </div><!-- End Message -->
          </div>
        </div>
        <!-- End Received Chat Bubble -->
      </li>
    `;
        $('#chatBubblesList').append(messageHTML);
        // Optionally, scroll to the latest message
        $('#chatBubblesList').scrollTop($('#chatBubblesList')[0].scrollHeight);
    }

    // Example usage: Append a new received message
    const exampleMessage = {
        avatar: "https://images.unsplash.com/photo-1601935111741-ae98b2b230b0?ixlib=rb-4.0.3&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=facearea&facepad=2.5&w=320&h=320&q=80",
        sender: "Costa",
        filename: "preline-ui.zip",
        filesize: "1.2 MB",
        downloadLink: "#",
        timestamp: "11:45"
    };

    // Append the example message (for demonstration)
    appendReceivedMessage(exampleMessage);

    // Add more functions as needed to handle dynamic message rendering
});
