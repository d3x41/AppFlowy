use std::any::Any;
use std::sync::Arc;

use collab::core::collab::IndexContentReceiver;
use collab_folder::{folder_diff::FolderViewChange, View, ViewIcon, ViewLayout};
use flowy_error::FlowyError;
use uuid::Uuid;

pub struct IndexableData {
  pub id: String,
  pub data: String,
  pub icon: Option<ViewIcon>,
  pub layout: ViewLayout,
  pub workspace_id: Uuid,
}

impl IndexableData {
  pub fn from_view(view: Arc<View>, workspace_id: Uuid) -> Self {
    IndexableData {
      id: view.id.clone(),
      data: view.name.clone(),
      icon: view.icon.clone(),
      layout: view.layout.clone(),
      workspace_id,
    }
  }
}

pub trait IndexManager: Send + Sync {
  fn set_index_content_receiver(&self, rx: IndexContentReceiver, workspace_id: Uuid);
  fn add_index(&self, data: IndexableData) -> Result<(), FlowyError>;
  fn update_index(&self, data: IndexableData) -> Result<(), FlowyError>;
  fn remove_indices(&self, ids: Vec<String>) -> Result<(), FlowyError>;
  fn remove_indices_for_workspace(&self, workspace_id: Uuid) -> Result<(), FlowyError>;
  fn is_indexed(&self) -> bool;

  fn as_any(&self) -> &dyn Any;
}

pub trait FolderIndexManager: IndexManager {
  fn index_all_views(&self, views: Vec<Arc<View>>, workspace_id: Uuid);
  fn index_view_changes(
    &self,
    views: Vec<Arc<View>>,
    changes: Vec<FolderViewChange>,
    workspace_id: Uuid,
  );
}
