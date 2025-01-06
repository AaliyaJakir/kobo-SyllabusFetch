#ifndef SYLLABUSFETCH_PLUGIN_H
#define SYLLABUSFETCH_PLUGIN_H

#include <QObject>
#include <QDialog>
#include <QVBoxLayout>
#include <QLabel>
#include <QPushButton>
#include <QListWidget>
#include <QDir>
#include <QFile>
#include <QProcess>
#include <QEvent>
#include <QMouseEvent>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include "NPDialog.h"
#include "../NPGuiInterface.h"

struct CourseInfo {
    QString url;
    QString title;
    double score;
};

class SyllabusFetch : public QObject, public NPGuiInterface
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID NPGuiInterfaceIID FILE "SyllabusFetch.json")
    Q_INTERFACES(NPGuiInterface)

    public:
        SyllabusFetch();
        ~SyllabusFetch();
        void showUi();

    protected:
        bool eventFilter(QObject *obj, QEvent *event) override;

    private slots:
        void onNotebookSelected();
        void onCourseSelected();
        void onSearchFinished(int exitCode, QProcess::ExitStatus exitStatus);
        void onSyllabusFinished(int exitCode, QProcess::ExitStatus exitStatus);

    private:
        void showNotebookSelection();
        void showCourseSelection(const QString &response);
        void fetchSyllabus(const QString &courseUrl);
        void clearLayout();
        void cleanupProcess();
        void showErrorMessage(const QString& message, bool isWarning = false);
        
        NPDialog m_dlg;
        QListWidget* m_listWidget;
        QProcess* m_process;
        QList<CourseInfo> m_courses;
        QString m_selectedNotebook;
        const QString NOTEBOOKS_PATH = "/mnt/onboard/Exported Notebooks";
        const QString SEARCH_SCRIPT = "/mnt/onboard/.adds/syllabusFetch/ocw_search.sh";
        const QString FETCH_SCRIPT = "/mnt/onboard/.adds/syllabusFetch/ocw_fetch.sh";
};

#endif // SYLLABUSFETCH_PLUGIN_H