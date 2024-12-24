const express = require('express');
const router = express.Router();

// In-memory storage for messages (for demonstration purposes)
let messages = [];

// Function to render chat bubbles HTML
function renderChatBubbles(req, res) {
    res.sendFile('/e-commerce/catalog/products/messages/chat_bubbles/chat_bubbles.html', { root: __dirname });
}

// Handle sending a new message
function handleSendMessage(req, res) {
    const { sender, message, avatar, timestamp } = req.body;
    if (!sender || !message || !avatar || !timestamp) {
        return res.status(400).json({ error: 'Missing required fields.' });
    }

    const newMessage = { sender, message, avatar, timestamp };
    messages.push(newMessage);
    res.status(201).json({ success: true, message: newMessage });
}

// Handle editing a message
function handleEditMessage(req, res) {
    const { index, newMessage } = req.body;
    if (index === undefined || !newMessage) {
        return res.status(400).json({ error: 'Missing required fields.' });
    }

    if (index < 0 || index >= messages.length) {
        return res.status(404).json({ error: 'Message not found.' });
    }

    messages[index].message = newMessage;
    res.json({ success: true, message: messages[index] });
}

// Handle deleting a message
function handleDeleteMessage(req, res) {
    const { index } = req.body;
    if (index === undefined) {
        return res.status(400).json({ error: 'Missing required fields.' });
    }

    if (index < 0 || index >= messages.length) {
        return res.status(404).json({ error: 'Message not found.' });
    }

    const deletedMessage = messages.splice(index, 1);
    res.json({ success: true, message: deletedMessage[0] });
}

// Routes
router.get('/chat-bubbles', renderChatBubbles);
router.post('/api/chat/send', express.json(), handleSendMessage);
router.put('/api/chat/edit', express.json(), handleEditMessage);
router.delete('/api/chat/delete', express.json(), handleDeleteMessage);

module.exports = router;
