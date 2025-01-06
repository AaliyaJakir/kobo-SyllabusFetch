#include <QDebug>
#include <QMessageBox>
#include <QApplication>
#include "syllabusTest2.h"

syllabusTest2::syllabusTest2() : m_listWidget(nullptr), m_process(nullptr)
{
    // Constructor
}

syllabusTest2::~syllabusTest2()
{
    cleanupProcess();
}

void syllabusTest2::showUi()
{
    // Clear any previous state
    m_courses.clear();
    m_selectedNotebook.clear();
    cleanupProcess();
    
    // Ensure complete widget cleanup
    clearLayout();
    
    // Delete any existing widgets that might be lingering
    QList<QWidget*> widgets = m_dlg.findChildren<QWidget*>();
    for (QWidget* widget : widgets) {
        widget->hide();
        widget->deleteLater();
    }
    
    // Reset the dialog
    m_dlg.hide();
    m_dlg.setLayout(nullptr);
    
    // Now show the initial screen
    showNotebookSelection();
}

void syllabusTest2::showNotebookSelection()
{
    clearLayout();
    
    // Create layout with margins
    QVBoxLayout* layout = new QVBoxLayout(&m_dlg);
    layout->setContentsMargins(20, 20, 20, 20);
    layout->setSpacing(15);
    
    // Add title label with improved styling
    QLabel* label = new QLabel("Select a notebook to search MIT OCW:", &m_dlg);
    label->setStyleSheet(
        "QLabel {"
        "    font-size: 32px;"
        "    color: #333333;"
        "    padding: 10px;"
        "    margin-bottom: 10px;"
        "    border-bottom: 2px solid #CCCCCC;"
        "}"
    );
    layout->addWidget(label);

    // Create scroll buttons container
    QHBoxLayout* scrollLayout = new QHBoxLayout();
    
    // Common button style for scroll buttons
    QString scrollButtonStyle = 
        "QPushButton {"
        "    font-size: 24px;"
        "    padding: 10px 20px;"
        "    border-radius: 8px;"
        "    border: none;"
        "    color: white;"
        "    background-color: #607D8B;"  // Blue-gray color
        "}"
        "QPushButton:pressed {"
        "    background-color: #455A64;"
        "}";

    // Add up button
    QPushButton* upButton = new QPushButton("▲ Up", &m_dlg);
    upButton->setStyleSheet(scrollButtonStyle);
    upButton->installEventFilter(this);
    connect(upButton, &QPushButton::clicked, this, [this]() {
        int currentRow = m_listWidget->currentRow();
        int targetRow = std::max(0, currentRow - 5);
        m_listWidget->setCurrentRow(targetRow);
        m_listWidget->scrollToItem(m_listWidget->item(targetRow));
    });
    scrollLayout->addWidget(upButton);

    // Add down button
    QPushButton* downButton = new QPushButton("▼ Down", &m_dlg);
    downButton->setStyleSheet(scrollButtonStyle);
    downButton->installEventFilter(this);
    connect(downButton, &QPushButton::clicked, this, [this]() {
        int currentRow = m_listWidget->currentRow();
        int targetRow = std::min(m_listWidget->count() - 1, currentRow + 5);
        m_listWidget->setCurrentRow(targetRow);
        m_listWidget->scrollToItem(m_listWidget->item(targetRow));
    });
    scrollLayout->addWidget(downButton);

    layout->addLayout(scrollLayout);

    // Create list widget with improved styling
    m_listWidget = new QListWidget(&m_dlg);
    m_listWidget->setStyleSheet(
        "QListWidget {"
        "    font-size: 36px;"
        "    border: 1px solid #CCCCCC;"
        "    border-radius: 8px;"
        "    padding: 5px;"
        "    background-color: white;"
        "}"
        "QListWidget::item {"
        "    padding: 15px;"
        "    border-bottom: 1px solid #EEEEEE;"
        "}"
        "QListWidget::item:selected {"
        "    background-color: #2196F3;"
        "    color: white;"
        "}"
        "QListWidget::item:hover {"
        "    background-color: #F5F5F5;"
        "}"
    );
    m_listWidget->setHorizontalScrollBarPolicy(Qt::ScrollBarAlwaysOff);
    m_listWidget->setWordWrap(true);
    m_listWidget->installEventFilter(this);

    // Load notebooks from directory
    QDir dir(NOTEBOOKS_PATH);
    QStringList notebooks = dir.entryList(QStringList() << "*.txt", QDir::Files);
    m_listWidget->addItems(notebooks);
    layout->addWidget(m_listWidget);

    // Create button container with spacing
    QHBoxLayout* buttonLayout = new QHBoxLayout();
    buttonLayout->setSpacing(15);
    buttonLayout->setContentsMargins(0, 10, 0, 0);

    // Common button style
    QString buttonStyle = 
        "QPushButton {"
        "    font-size: 28px;"
        "    padding: 15px 30px;"
        "    border-radius: 8px;"
        "    border: none;"
        "    color: white;"
        "    min-width: 150px;"
        "}"
        "QPushButton:pressed {"
        "    padding-top: 17px;"
        "    padding-bottom: 13px;"
        "}";

    // Add select button first (on top) with green styling
    QPushButton* selectButton = new QPushButton("Select", &m_dlg);
    selectButton->setStyleSheet(buttonStyle +
        "QPushButton {"
        "    background-color: #2E7D32;"
        "}"
        "QPushButton:pressed {"
        "    background-color: #1B5E20;"
        "}"
    );
    selectButton->installEventFilter(this);
    connect(selectButton, &QPushButton::clicked, this, &syllabusTest2::onNotebookSelected);
    buttonLayout->addWidget(selectButton);

    // Add exit button second (on bottom) with red styling
    QPushButton* exitButton = new QPushButton("Exit", &m_dlg);
    exitButton->setStyleSheet(buttonStyle +
        "QPushButton {"
        "    background-color: #D32F2F;"
        "}"
        "QPushButton:pressed {"
        "    background-color: #B71C1C;"
        "}"
    );
    exitButton->installEventFilter(this);
    connect(exitButton, &QPushButton::clicked, &m_dlg, &QDialog::reject);
    buttonLayout->addWidget(exitButton);

    layout->addLayout(buttonLayout);
    m_dlg.setLayout(layout);
    m_dlg.showDlg();
}

void syllabusTest2::onNotebookSelected()
{
    QListWidgetItem* item = m_listWidget->currentItem();
    if (!item) {
        showErrorMessage("Please select a notebook first.", true);
        return;
    }

    m_selectedNotebook = NOTEBOOKS_PATH + "/" + item->text();

    // Clear layout and show loading message with improved styling
    clearLayout();
    QVBoxLayout* layout = new QVBoxLayout(&m_dlg);
    layout->setContentsMargins(20, 20, 20, 20);
    
    QLabel* loadingLabel = new QLabel("Searching for courses...", &m_dlg);
    loadingLabel->setStyleSheet(
        "QLabel {"
        "    font-size: 32px;"
        "    color: #333333;"
        "    padding: 20px;"
        "    margin: 20px;"
        "    border: 1px solid #CCCCCC;"
        "    border-radius: 8px;"
        "    background-color: #F5F5F5;"
        "    text-align: center;"
        "}"
    );
    layout->addWidget(loadingLabel, 0, Qt::AlignCenter);
    m_dlg.setLayout(layout);

    // Start the search process
    cleanupProcess();
    m_process = new QProcess(this);
    connect(m_process, static_cast<void(QProcess::*)(int, QProcess::ExitStatus)>(&QProcess::finished),
            this, &syllabusTest2::onSearchFinished);

    QStringList arguments;
    arguments << m_selectedNotebook;
    m_process->start(SEARCH_SCRIPT, arguments);
}

void syllabusTest2::onSearchFinished(int exitCode, QProcess::ExitStatus exitStatus)
{
    if (exitCode == 0 && exitStatus == QProcess::NormalExit) {
        QString response = m_process->readAllStandardOutput();
        showCourseSelection(response);
    } else {
        QString error = m_process->readAllStandardError();
        showErrorMessage("Failed to search courses.\n" + 
            (error.isEmpty() ? "Unknown error occurred." : error));
    }
    cleanupProcess();
}

void syllabusTest2::showCourseSelection(const QString &response)
{
    // Parse JSON response
    QJsonDocument doc = QJsonDocument::fromJson(response.toUtf8());
    QJsonObject jsonObj = doc.object();
    if (!doc.isObject() || !jsonObj.value("success").toBool()) {
        showErrorMessage("Failed to connect to server.\nPlease check your WiFi connection.");
        return;
    }

    // Extract courses
    m_courses.clear();
    QJsonArray results = jsonObj.value("results").toArray();
    for (const QJsonValue &val : results) {
        QJsonObject obj = val.toObject();
        CourseInfo course;
        course.url = obj.value("url").toString();
        course.title = obj.value("text").toString();
        course.score = obj.value("score").toDouble();
        m_courses.append(course);
    }

    if (m_courses.isEmpty()) {
        showErrorMessage("No courses found for your query.", true);
        return;
    }

    // Show course selection UI
    clearLayout();
    QVBoxLayout* layout = new QVBoxLayout(&m_dlg);
    layout->setContentsMargins(20, 20, 20, 20);
    layout->setSpacing(15);
    
    QLabel* label = new QLabel("Select a course:", &m_dlg);
    label->setStyleSheet(
        "QLabel {"
        "    font-size: 32px;"
        "    color: #333333;"
        "    padding: 10px;"
        "    margin-bottom: 10px;"
        "    border-bottom: 2px solid #CCCCCC;"
        "}"
    );
    layout->addWidget(label);

    // Create list widget with improved styling
    m_listWidget = new QListWidget(&m_dlg);
    m_listWidget->setStyleSheet(
        "QListWidget {"
        "    font-size: 36px;"
        "    border: 1px solid #CCCCCC;"
        "    border-radius: 8px;"
        "    padding: 5px;"
        "    background-color: white;"
        "}"
        "QListWidget::item {"
        "    padding: 15px;"
        "    border-bottom: 1px solid #EEEEEE;"
        "}"
        "QListWidget::item:selected {"
        "    background-color: #2196F3;"
        "    color: white;"
        "}"
        "QListWidget::item:hover {"
        "    background-color: #F5F5F5;"
        "}"
    );
    m_listWidget->setHorizontalScrollBarPolicy(Qt::ScrollBarAlwaysOff);
    m_listWidget->setWordWrap(true);
    m_listWidget->installEventFilter(this);

    // Add courses
    QStringList courseTitles;
    for (const CourseInfo &course : m_courses) {
        courseTitles << course.title;
    }
    m_listWidget->addItems(courseTitles);
    layout->addWidget(m_listWidget);

    // Create button container with spacing
    QHBoxLayout* buttonLayout = new QHBoxLayout();
    buttonLayout->setSpacing(15);
    buttonLayout->setContentsMargins(0, 10, 0, 0);

    // Common button style
    QString buttonStyle = 
        "QPushButton {"
        "    font-size: 28px;"
        "    padding: 15px 30px;"
        "    border-radius: 8px;"
        "    border: none;"
        "    color: white;"
        "    min-width: 150px;"
        "}"
        "QPushButton:pressed {"
        "    padding-top: 17px;"
        "    padding-bottom: 13px;"
        "}";

    // Add get syllabus button first (on top) with blue styling
    QPushButton* selectButton = new QPushButton("Get Syllabus", &m_dlg);
    selectButton->setStyleSheet(buttonStyle +
        "QPushButton {"
        "    background-color: #1976D2;"
        "}"
        "QPushButton:pressed {"
        "    background-color: #0D47A1;"
        "}"
    );
    selectButton->installEventFilter(this);
    connect(selectButton, &QPushButton::clicked, this, &syllabusTest2::onCourseSelected);
    buttonLayout->addWidget(selectButton);

    // Add exit button second (on bottom) with red styling
    QPushButton* exitButton = new QPushButton("Exit", &m_dlg);
    exitButton->setStyleSheet(buttonStyle +
        "QPushButton {"
        "    background-color: #D32F2F;"
        "}"
        "QPushButton:pressed {"
        "    background-color: #B71C1C;"
        "}"
    );
    exitButton->installEventFilter(this);
    connect(exitButton, &QPushButton::clicked, &m_dlg, &QDialog::reject);
    buttonLayout->addWidget(exitButton);

    layout->addLayout(buttonLayout);
    m_dlg.setLayout(layout);
    m_dlg.showDlg();
}

void syllabusTest2::onCourseSelected()
{
    int index = m_listWidget->currentRow();
    if (index < 0 || index >= m_courses.size()) {
        showErrorMessage("Please select a course first.", true);
        return;
    }

    // Show loading message with improved styling
    clearLayout();
    QVBoxLayout* layout = new QVBoxLayout(&m_dlg);
    layout->setContentsMargins(20, 20, 20, 20);
    
    QLabel* loadingLabel = new QLabel("Fetching syllabus...", &m_dlg);
    loadingLabel->setStyleSheet(
        "QLabel {"
        "    font-size: 32px;"
        "    color: #333333;"
        "    padding: 20px;"
        "    margin: 20px;"
        "    border: 1px solid #CCCCCC;"
        "    border-radius: 8px;"
        "    background-color: #F5F5F5;"
        "    text-align: center;"
        "}"
    );
    layout->addWidget(loadingLabel, 0, Qt::AlignCenter);
    m_dlg.setLayout(layout);

    // Start syllabus fetch
    fetchSyllabus(m_courses[index].url);
}

void syllabusTest2::fetchSyllabus(const QString &courseUrl)
{
    cleanupProcess();
    m_process = new QProcess(this);
    connect(m_process, static_cast<void(QProcess::*)(int, QProcess::ExitStatus)>(&QProcess::finished),
            this, &syllabusTest2::onSyllabusFinished);

    QStringList arguments;
    arguments << courseUrl;
    m_process->start(FETCH_SCRIPT, arguments);
}

void syllabusTest2::onSyllabusFinished(int exitCode, QProcess::ExitStatus exitStatus)
{
    QString response = m_process->readAllStandardOutput();
    QString error = m_process->readAllStandardError();
    cleanupProcess();  // Clean up process first
    
    // First, completely destroy the old dialog
    m_dlg.reject();  // This will close and cleanup the current dialog
    m_dlg.hide();
    clearLayout();
    
    // Delete any existing widgets that might be lingering
    QList<QWidget*> widgets = m_dlg.findChildren<QWidget*>();
    for (QWidget* widget : widgets) {
        widget->setParent(nullptr);  // Unparent widgets
        widget->hide();
        widget->deleteLater();
    }
    
    // Create new layout
    QVBoxLayout* layout = new QVBoxLayout(&m_dlg);
    layout->setContentsMargins(20, 20, 20, 20);
    layout->setSpacing(15);

    // Create message label
    QLabel* messageLabel = new QLabel(&m_dlg);
    messageLabel->setWordWrap(true);
    messageLabel->setAlignment(Qt::AlignCenter);
    
    QString styleBase = 
        "QLabel {"
        "    font-size: 32px;"
        "    padding: 20px;"
        "    margin: 20px;"
        "    border-radius: 8px;"
        "    background-color: %1;"
        "    color: #333333;"
        "    border: 1px solid %2;"
        "}";
    
    if (exitCode == 0 && exitStatus == QProcess::NormalExit) {
        QJsonDocument doc = QJsonDocument::fromJson(response.toUtf8());
        QJsonObject jsonObj = doc.object();
        
        if (doc.isObject() && jsonObj.value("success").toBool()) {
            QString message = jsonObj.value("message").toString();
            messageLabel->setText(message.isEmpty() ? "Your syllabus is coming soon!" : message);
            messageLabel->setStyleSheet(styleBase.arg("#E8F5E9", "#2E7D32")); // Light green background
        } else {
            QString jsonError = jsonObj.value("error").toString();
            if (jsonError.contains("connect") || jsonError.isEmpty()) {
                messageLabel->setText("Failed to connect to server.\nPlease check your WiFi connection.");
            } else {
                messageLabel->setText("Failed to fetch syllabus.\n" + jsonError);
            }
            messageLabel->setStyleSheet(styleBase.arg("#FFEBEE", "#D32F2F")); // Light red background
        }
    } else {
        if (error.contains("connect") || error.contains("network") || error.isEmpty()) {
            messageLabel->setText("Failed to connect to server.\nPlease check your WiFi connection.");
        } else {
            messageLabel->setText("Failed to fetch syllabus.\n" + error);
        }
        messageLabel->setStyleSheet(styleBase.arg("#FFEBEE", "#D32F2F")); // Light red background
    }
    
    layout->addWidget(messageLabel);

    // Add OK button with blue styling
    QPushButton* okButton = new QPushButton("OK", &m_dlg);
    QString buttonStyle = 
        "QPushButton {"
        "    font-size: 28px;"
        "    padding: 15px 30px;"
        "    border-radius: 8px;"
        "    border: none;"
        "    color: white;"
        "    min-width: 150px;"
        "    background-color: #1976D2;"
        "}"
        "QPushButton:pressed {"
        "    background-color: #0D47A1;"
        "    padding-top: 17px;"
        "    padding-bottom: 13px;"
        "}";
    
    okButton->setStyleSheet(buttonStyle);
    okButton->installEventFilter(this);
    connect(okButton, &QPushButton::clicked, &m_dlg, &QDialog::accept);
    
    // Center the button
    QHBoxLayout* buttonLayout = new QHBoxLayout();
    buttonLayout->addStretch();
    buttonLayout->addWidget(okButton);
    buttonLayout->addStretch();
    
    layout->addLayout(buttonLayout);
    
    // Set the new layout and show dialog
    m_dlg.setLayout(layout);
    m_dlg.showDlg();
}

bool syllabusTest2::eventFilter(QObject *obj, QEvent *event)
{
    // Handle list widget touch events
    if (QListWidget *list = qobject_cast<QListWidget*>(obj)) {
        if (event->type() == QEvent::TouchBegin ||
            event->type() == QEvent::TouchEnd ||
            event->type() == QEvent::TouchUpdate) {
            
            QTouchEvent *touchEvent = static_cast<QTouchEvent*>(event);
            if (!touchEvent->touchPoints().isEmpty()) {
                const QTouchEvent::TouchPoint &touchPoint = touchEvent->touchPoints().first();
                QPoint pos = touchPoint.pos().toPoint();
                
                if (event->type() == QEvent::TouchEnd) {
                    QListWidgetItem *item = list->itemAt(pos);
                    if (item) {
                        // Clear previous selection
                        for (int i = 0; i < list->count(); i++) {
                            list->item(i)->setSelected(false);
                        }
                        // Set new selection
                        item->setSelected(true);
                        list->setCurrentItem(item);
                        return true;
                    }
                }
            }
            return true;  // Always handle touch events for the list
        }
    }
    
    // Handle button touch events
    if (QPushButton *button = qobject_cast<QPushButton*>(obj)) {
        if (event->type() == QEvent::TouchBegin ||
            event->type() == QEvent::TouchEnd) {
            
            // Convert touch to mouse event
            QMouseEvent *mouseEvent = new QMouseEvent(
                event->type() == QEvent::TouchBegin ? QEvent::MouseButtonPress : QEvent::MouseButtonRelease,
                button->mapFromGlobal(QCursor::pos()),
                Qt::LeftButton,
                Qt::LeftButton,
                Qt::NoModifier
            );
            
            QApplication::postEvent(button, mouseEvent);
            return true;
        }
    }

    // Handle message box touch events
    if (QMessageBox *msgBox = qobject_cast<QMessageBox*>(obj)) {
        if (event->type() == QEvent::TouchBegin ||
            event->type() == QEvent::TouchEnd) {
            
            QTouchEvent *touchEvent = static_cast<QTouchEvent*>(event);
            if (!touchEvent->touchPoints().isEmpty()) {
                const QTouchEvent::TouchPoint &touchPoint = touchEvent->touchPoints().first();
                QPoint pos = touchPoint.pos().toPoint();
                
                // Find the OK button in the message box
                QList<QPushButton*> buttons = msgBox->findChildren<QPushButton*>();
                for (QPushButton* button : buttons) {
                    if (button->text().contains("OK", Qt::CaseInsensitive)) {
                        QRect buttonGeometry = button->geometry();
                        if (buttonGeometry.contains(pos)) {
                            if (event->type() == QEvent::TouchEnd) {
                                button->click();
                            }
                            return true;
                        }
                    }
                }
            }
        }
    }

    return QObject::eventFilter(obj, event);
}

void syllabusTest2::clearLayout()
{
    if (QLayout* layout = m_dlg.layout()) {
        QLayoutItem* item;
        while ((item = layout->takeAt(0)) != nullptr) {
            if (QWidget* widget = item->widget()) {
                widget->hide();
                widget->deleteLater();
            }
            delete item;
        }
        delete layout;
        m_dlg.setLayout(nullptr);  // Explicitly set layout to null after clearing
    }
    m_listWidget = nullptr;
}

void syllabusTest2::cleanupProcess()
{
    if (m_process) {
        m_process->disconnect();
        if (m_process->state() != QProcess::NotRunning) {
            m_process->terminate();
            m_process->waitForFinished();
        }
        m_process->deleteLater();
        m_process = nullptr;
    }
}

void syllabusTest2::showErrorMessage(const QString& message, bool isWarning)
{
    // Clear any existing content
    clearLayout();
    m_dlg.hide();
    
    QVBoxLayout* layout = new QVBoxLayout(&m_dlg);
    layout->setContentsMargins(20, 20, 20, 20);
    layout->setSpacing(15);

    // Create message label
    QLabel* messageLabel = new QLabel(&m_dlg);
    messageLabel->setText(message);
    messageLabel->setWordWrap(true);
    messageLabel->setAlignment(Qt::AlignCenter);
    
    QString styleBase = 
        "QLabel {"
        "    font-size: 32px;"
        "    padding: 20px;"
        "    margin: 20px;"
        "    border-radius: 8px;"
        "    background-color: %1;"
        "    color: #333333;"
        "    border: 1px solid %2;"
        "}";
    
    // Use orange for warnings, red for errors
    messageLabel->setStyleSheet(styleBase.arg(
        isWarning ? "#FFF3E0" : "#FFEBEE",
        isWarning ? "#F57C00" : "#D32F2F"
    ));
    
    layout->addWidget(messageLabel);

    // Add OK button
    QPushButton* okButton = new QPushButton("OK", &m_dlg);
    QString buttonStyle = 
        "QPushButton {"
        "    font-size: 28px;"
        "    padding: 15px 30px;"
        "    border-radius: 8px;"
        "    border: none;"
        "    color: white;"
        "    min-width: 150px;"
        "    background-color: #1976D2;"
        "}"
        "QPushButton:pressed {"
        "    background-color: #0D47A1;"
        "    padding-top: 17px;"
        "    padding-bottom: 13px;"
        "}";
    
    okButton->setStyleSheet(buttonStyle);
    okButton->installEventFilter(this);
    connect(okButton, &QPushButton::clicked, this, [this]() {
        clearLayout();
        m_dlg.hide();
        showNotebookSelection();
    });
    
    // Center the button
    QHBoxLayout* buttonLayout = new QHBoxLayout();
    buttonLayout->addStretch();
    buttonLayout->addWidget(okButton);
    buttonLayout->addStretch();
    
    layout->addLayout(buttonLayout);
    m_dlg.setLayout(layout);
    m_dlg.showDlg();
}